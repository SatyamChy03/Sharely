import 'dart:async';
import 'dart:io';

import 'package:sharely_core/src/pairing/paired_device.dart';
import 'package:sharely_core/src/protocol/protocol_message.dart';
import 'package:sharely_core/src/server/control_hub.dart';
import 'package:sharely_core/src/server/request_authenticator.dart';
import 'package:sharely_core/src/server/upload_intake.dart';
import 'package:sharely_core/src/transfer/incoming_transfer.dart';
import 'package:sharely_core/src/transfer/incoming_transfer_event.dart';
import 'package:sharely_core/src/transfer/resume_settings.dart';
import 'package:sharely_core/src/transfer/transfer_exception.dart';
import 'package:shelf/shelf.dart';

const _progressReportInterval = Duration(milliseconds: 100);

/// Laptop side of transfers: offers in, accepted files verified onto disk.
///
/// An upload that breaks off keeps its bytes; the phone continues it from
/// [handleOffset] once it is back, within [resumeWindow].
class TransferReceiver {
  new({
    required this.saveDirectory,
    ControlHub? hub,
    this.maxPendingOffersPerDevice = 3,
    this.maxOpenTransfersPerDevice = 8,
    this.offerLifetime = const Duration(minutes: 5),
    this.resumeWindow = defaultResumeWindow,
    this.dataIdleTimeout = defaultDataIdleTimeout,
  }) : hub = hub ?? ControlHub() {
    _subscriptions = [
      this.hub.messages.listen(_handleMessage),
      this.hub.disconnects.listen(_handleDisconnect),
    ];
  }

  /// Where accepted files are saved; created on first use.
  final Future<Directory> Function() saveDirectory;
  final ControlHub hub;

  /// Stops one paired device from flooding the screen with prompts.
  final int maxPendingOffersPerDevice;

  /// Caps unanswered and running transfers together, so a device whose
  /// offers are accepted automatically still cannot open them without end.
  final int maxOpenTransfersPerDevice;

  /// An offer nobody answers is withdrawn after this long.
  final Duration offerLifetime;

  /// How long an accepted transfer may receive nothing before it is ended.
  final Duration resumeWindow;

  /// How long one upload may stay silent before it counts as broken.
  final Duration dataIdleTimeout;

  final _transfers = <String, IncomingTransfer>{};
  late final _uploads = UploadIntake(
    findTransfer: (transferId) => _transfers[transferId],
    saveDirectory: saveDirectory,
    dataIdleTimeout: dataIdleTimeout,
    onBytesWritten: _recordProgress,
    onInterrupted: (transfer) =>
        _emit(IncomingTransferInterrupted(transfer.offer.transferId)),
    onIdle: _armStallTimer,
    onAllFilesSaved: _complete,
    onFailed: (transfer, reason) =>
        _end(transfer.offer.transferId, reason, notifySender: true),
  );
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
    _armStallTimer(transfer);
    hub.send(
      transfer.sender.deviceId,
      TransferDecisionMessage.accept(transferId),
    );
  }

  void reject(String transferId) {
    final transfer = _transfers.remove(transferId);
    if (transfer == null) return;
    transfer.isEnded = true;
    transfer.stallTimer?.cancel();
    hub.send(
      transfer.sender.deviceId,
      TransferDecisionMessage.reject(transferId),
    );
  }

  void cancel(String transferId) =>
      _end(transferId, TransferFailure.cancelled, notifySender: true);

  /// `PUT /v1/transfers/<transferId>/<fileIndex>`, behind [requirePairedDevice].
  Future<Response> handleUpload(Request request) =>
      _uploads.handleUpload(request);

  /// `GET /v1/transfers/<transferId>/<fileIndex>/offset`, behind
  /// [requirePairedDevice].
  Future<Response> handleOffset(Request request) =>
      _uploads.handleOffset(request);

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

  void _handleMessage(DeviceMessage deviceMessage) {
    final (:sender, :message) = deviceMessage;
    switch (message) {
      case OfferMessage():
        _registerOffer(sender, message);
      case TransferDecisionMessage(type: MessageType.cancel, :final transferId)
          when _transfers[transferId]?.isFrom(sender) ?? false:
        _end(transferId, TransferFailure.cancelled, notifySender: false);
      default:
        // Text and links are shown by the app, which listens to the hub.
        break;
    }
  }

  void _registerOffer(PairedDevice sender, OfferMessage offer) {
    final fromSender = _transfers.values.where(
      (transfer) => transfer.isFrom(sender),
    );
    final pendingFromSender = fromSender.where(
      (transfer) => transfer.stage == IncomingTransferStage.awaitingDecision,
    );
    if (_transfers.containsKey(offer.transferId) ||
        pendingFromSender.length >= maxPendingOffersPerDevice ||
        fromSender.length >= maxOpenTransfersPerDevice) {
      hub.send(
        sender.deviceId,
        TransferDecisionMessage.reject(offer.transferId),
      );
      return;
    }
    final transferId = offer.transferId;
    _transfers[transferId] = IncomingTransfer(sender: sender, offer: offer)
      ..stallTimer = Timer(
        offerLifetime,
        () => _end(transferId, TransferFailure.timedOut, notifySender: true),
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
    transfer.stallTimer?.cancel();
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
    transfer.stallTimer?.cancel();
    transfer.releaseUnfinishedFiles();
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

  void _armStallTimer(IncomingTransfer transfer) {
    transfer.stallTimer?.cancel();
    if (transfer.isEnded) return;
    transfer.stallTimer = Timer(
      resumeWindow,
      () => _end(
        transfer.offer.transferId,
        TransferFailure.unreachable,
        notifySender: true,
      ),
    );
  }

  /// A lost phone withdraws its unanswered offers; accepted transfers wait
  /// for it to come back and resume.
  void _handleDisconnect(String deviceId) {
    final fromDevice = _transfers.values
        .where((transfer) => transfer.sender.deviceId == deviceId)
        .toList();
    for (final transfer in fromDevice) {
      final transferId = transfer.offer.transferId;
      if (transfer.stage == IncomingTransferStage.awaitingDecision) {
        _end(transferId, TransferFailure.unreachable, notifySender: false);
      } else if (transfer.activeUploads.isEmpty) {
        _emit(IncomingTransferInterrupted(transferId));
      }
    }
  }
}
