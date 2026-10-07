import 'dart:async';
import 'dart:io';

import 'package:sharely_core/src/pairing/paired_device.dart';
import 'package:sharely_core/src/protocol/protocol_message.dart';
import 'package:sharely_core/src/security/file_safety_exception.dart';
import 'package:sharely_core/src/server/control_hub.dart';
import 'package:sharely_core/src/server/request_authenticator.dart';
import 'package:sharely_core/src/transfer/incoming_file_writer.dart';
import 'package:sharely_core/src/transfer/incoming_transfer.dart';
import 'package:sharely_core/src/transfer/incoming_transfer_event.dart';
import 'package:sharely_core/src/transfer/transfer_exception.dart';
import 'package:sharely_core/src/transfer/upload_checksum.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

const _progressReportInterval = Duration(milliseconds: 100);

/// Laptop side of transfers: offers in, accepted files verified onto disk.
class TransferReceiver {
  new({
    required this.saveDirectory,
    ControlHub? hub,
    this.maxPendingOffersPerDevice = 3,
  }) : hub = hub ?? ControlHub() {
    _subscriptions = [
      this.hub.messages.listen(_handleMessage),
      this.hub.disconnects.listen(_endTransfersFrom),
    ];
  }

  /// Where accepted files are saved; created on first use.
  final Future<Directory> Function() saveDirectory;
  final ControlHub hub;

  /// Stops one paired device from flooding the screen with prompts.
  final int maxPendingOffersPerDevice;

  final _transfers = <String, IncomingTransfer>{};
  final _events = StreamController<IncomingTransferEvent>.broadcast();
  late final List<StreamSubscription<Object>> _subscriptions;

  Stream<IncomingTransferEvent> get events => _events.stream;

  void accept(String transferId) {
    final transfer = _transfers[transferId];
    if (transfer == null ||
        transfer.stage != IncomingTransferStage.awaitingDecision) {
      return;
    }
    transfer.stage = IncomingTransferStage.receiving;
    hub.send(
      transfer.sender.deviceId,
      TransferDecisionMessage.accept(transferId),
    );
  }

  void reject(String transferId) {
    final transfer = _transfers.remove(transferId);
    if (transfer == null) return;
    transfer.isEnded = true;
    hub.send(
      transfer.sender.deviceId,
      TransferDecisionMessage.reject(transferId),
    );
  }

  void cancel(String transferId) =>
      _end(transferId, TransferFailure.cancelled, notifySender: true);

  /// `PUT /v1/transfers/<transferId>/<fileIndex>`, behind [requirePairedDevice].
  Future<Response> handleUpload(Request request) async {
    final transferId = request.params['transferId'] ?? '';
    final transfer = _transfers[transferId];
    final fileIndex = int.tryParse(request.params['fileIndex'] ?? '') ?? -1;
    // Unknown, foreign and out-of-range uploads all look the same: not found.
    if (transfer == null ||
        !transfer.isFrom(authenticatedDevice(request)) ||
        fileIndex < 0 ||
        fileIndex >= transfer.offer.files.length) {
      return Response.notFound(null);
    }
    if (transfer.stage != IncomingTransferStage.receiving ||
        !transfer.startedFileIndexes.add(fileIndex)) {
      return Response(HttpStatus.conflict);
    }
    final expected = transfer.offer.files[fileIndex];
    final declaredLength = request.contentLength;
    if (declaredLength != null &&
        declaredLength != expected.sizeBytes + uploadChecksumBytes) {
      _end(transferId, TransferFailure.corrupted, notifySender: true);
      return Response.badRequest();
    }
    return await _receiveFile(transfer, expected, request.read());
  }

  Future<void> close() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    for (final transferId in [..._transfers.keys]) {
      _end(transferId, TransferFailure.cancelled, notifySender: true);
    }
    await hub.closeAll();
    await _events.close();
  }

  Future<Response> _receiveFile(
    IncomingTransfer transfer,
    OfferedFile expected,
    Stream<List<int>> body,
  ) async {
    final transferId = transfer.offer.transferId;
    try {
      final directory = await saveDirectory();
      await directory.create(recursive: true);
      final file = await writeIncomingFile(
        body: body,
        saveDirectory: directory,
        expected: expected,
        isCancelled: () => transfer.isEnded,
        onBytesWritten: (byteCount) => _recordProgress(transfer, byteCount),
      );
      transfer.savedFiles.add(file);
    } on TransferException catch (error) {
      _end(transferId, error.failure, notifySender: true);
      return error.failure == TransferFailure.corrupted
          ? Response(HttpStatus.unprocessableEntity)
          : Response(HttpStatus.conflict);
    } on IOException {
      _end(transferId, TransferFailure.unreachable, notifySender: true);
      return Response(HttpStatus.conflict);
    } on FileSafetyException {
      _end(transferId, TransferFailure.refused, notifySender: true);
      return Response(HttpStatus.conflict);
    }
    if (transfer.hasAllFiles) _complete(transfer);
    return Response(HttpStatus.noContent);
  }

  void _handleMessage(DeviceMessage deviceMessage) {
    final (:sender, :message) = deviceMessage;
    switch (message) {
      case OfferMessage():
        _registerOffer(sender, message);
      case TransferDecisionMessage(type: MessageType.cancel, :final transferId)
          when _transfers[transferId]?.isFrom(sender) ?? false:
        _end(transferId, TransferFailure.cancelled, notifySender: false);
      default:
        // Text, links and clipboard arrive in a later slice; ignore for now.
        break;
    }
  }

  void _registerOffer(PairedDevice sender, OfferMessage offer) {
    final pendingFromSender = _transfers.values.where(
      (transfer) =>
          transfer.isFrom(sender) &&
          transfer.stage == IncomingTransferStage.awaitingDecision,
    );
    if (_transfers.containsKey(offer.transferId) ||
        pendingFromSender.length >= maxPendingOffersPerDevice) {
      hub.send(
        sender.deviceId,
        TransferDecisionMessage.reject(offer.transferId),
      );
      return;
    }
    _transfers[offer.transferId] = IncomingTransfer(
      sender: sender,
      offer: offer,
    );
    _emit(IncomingOfferReceived(sender: sender, offer: offer));
  }

  void _recordProgress(IncomingTransfer transfer, int byteCount) {
    transfer.bytesReceived += byteCount;
    final totalBytes = transfer.offer.totalBytes;
    final isLastByte = transfer.bytesReceived == totalBytes;
    if (!isLastByte &&
        transfer.sinceLastProgressReport.elapsed < _progressReportInterval) {
      return;
    }
    transfer.sinceLastProgressReport.reset();
    _emit(
      IncomingTransferProgressed(
        transfer.offer.transferId,
        bytesReceived: transfer.bytesReceived,
        totalBytes: totalBytes,
      ),
    );
  }

  void _complete(IncomingTransfer transfer) {
    final transferId = transfer.offer.transferId;
    _transfers.remove(transferId);
    transfer.isEnded = true;
    _emit(
      IncomingTransferCompleted(
        transferId,
        savedFiles: List.unmodifiable(transfer.savedFiles),
      ),
    );
  }

  void _end(
    String transferId,
    TransferFailure reason, {
    required bool notifySender,
  }) {
    final transfer = _transfers.remove(transferId);
    if (transfer == null) return;
    transfer.isEnded = true;
    if (notifySender) {
      hub.send(
        transfer.sender.deviceId,
        TransferDecisionMessage.cancel(transferId),
      );
    }
    _emit(IncomingTransferEnded(transferId, reason: reason));
  }

  // Uploads still in flight may report after close(); drop those events.
  void _emit(IncomingTransferEvent event) {
    if (!_events.isClosed) _events.add(event);
  }

  void _endTransfersFrom(String deviceId) {
    final fromDevice = [
      for (final MapEntry(:key, :value) in _transfers.entries)
        if (value.sender.deviceId == deviceId) key,
    ];
    for (final transferId in fromDevice) {
      _end(transferId, TransferFailure.unreachable, notifySender: false);
    }
  }
}
