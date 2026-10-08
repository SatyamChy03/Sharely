import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:sharely_core/src/protocol/message_codec.dart';
import 'package:sharely_core/src/protocol/protocol_limits.dart';
import 'package:sharely_core/src/protocol/protocol_message.dart';
import 'package:sharely_core/src/security/file_name_sanitizer.dart';
import 'package:sharely_core/src/security/secure_id.dart';
import 'package:sharely_core/src/server/control_hub.dart';
import 'package:sharely_core/src/server/request_authenticator.dart';
import 'package:sharely_core/src/transfer/checksummed_file_stream.dart';
import 'package:sharely_core/src/transfer/offered_transfer.dart';
import 'package:sharely_core/src/transfer/outgoing_file.dart';
import 'package:sharely_core/src/transfer/outgoing_transfer_update.dart';
import 'package:sharely_core/src/transfer/resume_settings.dart';
import 'package:sharely_core/src/transfer/transfer_exception.dart';
import 'package:sharely_core/src/transfer/upload_checksum.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

const _progressReportInterval = Duration(milliseconds: 100);

/// What just happened to one transfer this laptop is sending.
typedef SentTransferEvent = ({
  String transferId,
  OutgoingTransferUpdate update,
});

/// Laptop side of sending: offers out, accepted files served for download.
///
/// A download that breaks off can be asked for again from any byte, until
/// nothing has moved for [resumeWindow].
class TransferSender {
  new({
    required this.hub,
    this.decisionTimeout = const Duration(minutes: 2),
    this.resumeWindow = defaultResumeWindow,
  }) {
    _subscriptions = [
      hub.messages.listen(_handleMessage),
      hub.disconnects.listen(_handleDisconnect),
    ];
  }

  final ControlHub hub;

  /// How long the phone has to answer before the offer is withdrawn.
  final Duration decisionTimeout;

  /// How long an accepted transfer may send nothing before it is ended.
  final Duration resumeWindow;

  final _transfers = <String, OfferedTransfer>{};
  final _events = StreamController<SentTransferEvent>.broadcast();
  late final List<StreamSubscription<Object>> _subscriptions;

  Stream<SentTransferEvent> get events => _events.stream;

  /// Offers [files] to a paired device and returns the new transfer's id.
  ///
  /// Throws [TransferException]: `unreachable` when the device has no control
  /// connection, `noFiles` for an empty list, and `tooManyFiles` when the
  /// offer would not fit in one message.
  String offerFiles({
    required String deviceId,
    required List<OutgoingFile> files,
  }) {
    if (files.isEmpty) throw const TransferException(TransferFailure.noFiles);
    final offer = OfferMessage(
      transferId: generateSecureId(),
      files: [
        for (final file in files)
          OfferedFile(
            // Local names can hold characters the receiver's parser rejects.
            name: sanitizeFileName(file.name),
            sizeBytes: file.sizeBytes,
            mimeType: file.mimeType,
          ),
      ],
    );
    if (files.length > ProtocolLimits.maxFilesPerOffer ||
        MessageCodec.encode(offer).length > ProtocolLimits.maxMessageChars) {
      throw const TransferException(TransferFailure.tooManyFiles);
    }
    if (!hub.send(deviceId, offer)) {
      throw const TransferException(TransferFailure.unreachable);
    }
    final transferId = offer.transferId;
    _transfers[transferId] = OfferedTransfer(
      deviceId: deviceId,
      files: List.unmodifiable(files),
      decisionTimer: Timer(
        decisionTimeout,
        () => _end(transferId, TransferFailure.timedOut, notifyReceiver: true),
      ),
    );
    return transferId;
  }

  void cancel(String transferId) =>
      _end(transferId, TransferFailure.cancelled, notifyReceiver: true);

  /// `GET /v1/transfers/<transferId>/<fileIndex>`, behind [requirePairedDevice].
  Response handleDownload(Request request) {
    final transferId = request.params['transferId'] ?? '';
    final transfer = _transfers[transferId];
    final fileIndex = int.tryParse(request.params['fileIndex'] ?? '') ?? -1;
    // Unknown, foreign and out-of-range requests all look the same: not found.
    if (transfer == null ||
        transfer.deviceId != authenticatedDevice(request).deviceId ||
        fileIndex < 0 ||
        fileIndex >= transfer.files.length) {
      return Response.notFound(null);
    }
    final file = transfer.files[fileIndex];
    final offset = int.tryParse(request.headers[resumeOffsetHeader] ?? '0');
    if (offset == null || offset < 0 || offset > file.sizeBytes) {
      return Response.badRequest();
    }
    if (!transfer.isAccepted) return Response(HttpStatus.conflict);
    final serve = Object();
    transfer.currentServes[fileIndex] = serve;
    transfer.stallTimer?.cancel();
    // Written to the socket directly: a send that stops early has to drop
    // the connection, which an ordinary response body cannot do cleanly.
    request.hijack((channel) {
      channel.stream.drain<void>().ignore();
      unawaited(
        _writeDownload(
          channel.sink,
          sizeBytes: file.sizeBytes - offset,
          body: _serveFile(transferId, transfer, fileIndex, offset, serve),
        ),
      );
    });
  }

  Future<void> _writeDownload(
    StreamSink<List<int>> socket, {
    required int sizeBytes,
    required Stream<List<int>> body,
  }) async {
    final head =
        'HTTP/1.1 200 OK\r\n'
        'content-type: application/octet-stream\r\n'
        'content-length: ${sizeBytes + uploadChecksumBytes}\r\n'
        'cache-control: no-store\r\n'
        'connection: close\r\n\r\n';
    try {
      socket.add(ascii.encode(head));
      await socket.addStream(body);
      await socket.close();
    } on IOException {
      // The phone went away; the body stream has already ended the transfer.
      socket.close().ignore();
    }
  }

  Future<void> close() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    for (final transferId in [..._transfers.keys]) {
      _end(transferId, TransferFailure.cancelled, notifyReceiver: true);
    }
    await _events.close();
  }

  /// The file from [offset], then its checksum.
  ///
  /// Ending short of the declared length closes the connection early, which
  /// is how the phone learns the file is incomplete.
  Stream<List<int>> _serveFile(
    String transferId,
    OfferedTransfer transfer,
    int fileIndex,
    int offset,
    Object serve,
  ) async* {
    var bytesSent = transfer.bytesBefore(fileIndex) + offset;
    var isServed = false;
    try {
      final chunks = readFileWithChecksum(
        transfer.files[fileIndex],
        offset: offset,
        shouldStop: () => !transfer.isServing(fileIndex, serve),
        onBytesYielded: (byteCount) {
          bytesSent += byteCount;
          _recordProgress(transferId, transfer, bytesSent);
        },
      );
      // Not `yield*`: that would hand a read error to the socket instead of
      // to the handler below.
      await for (final chunk in chunks) {
        yield chunk;
      }
      isServed = transfer.isServing(fileIndex, serve);
    } on FileSystemException {
      if (transfer.isServing(fileIndex, serve)) {
        _end(transferId, TransferFailure.unreadableFile, notifyReceiver: true);
      }
    } finally {
      // A newer download of this file has taken over; leave its state alone.
      if (transfer.isServing(fileIndex, serve)) {
        transfer.currentServes.remove(fileIndex);
        if (!isServed) _emit(transferId, const OutgoingTransferReconnecting());
        if (transfer.currentServes.isEmpty) {
          _armStallTimer(transferId, transfer);
        }
      }
    }
  }

  void _handleMessage(DeviceMessage deviceMessage) {
    final (:sender, :message) = deviceMessage;
    final transferId = switch (message) {
      TransferDecisionMessage(:final transferId) => transferId,
      ProgressMessage(:final transferId) => transferId,
      _ => null,
    };
    final transfer = _transfers[transferId];
    if (transferId == null ||
        transfer == null ||
        transfer.deviceId != sender.deviceId) {
      return;
    }
    switch (message) {
      case TransferDecisionMessage(type: MessageType.accept):
        _markAccepted(transferId, transfer);
      case TransferDecisionMessage(type: MessageType.reject):
        _end(transferId, TransferFailure.rejected, notifyReceiver: false);
      case TransferDecisionMessage(type: MessageType.cancel):
        _end(transferId, TransferFailure.cancelled, notifyReceiver: false);
      // The phone reports the full size only once every file is verified.
      case ProgressMessage(:final bytes)
          when transfer.isAccepted && bytes == transfer.totalBytes:
        _complete(transferId, transfer);
      default:
        break;
    }
  }

  void _markAccepted(String transferId, OfferedTransfer transfer) {
    if (transfer.isAccepted) return;
    transfer.isAccepted = true;
    transfer.decisionTimer.cancel();
    _armStallTimer(transferId, transfer);
    _emit(
      transferId,
      OutgoingTransferSending(bytesSent: 0, totalBytes: transfer.totalBytes),
    );
  }

  void _recordProgress(
    String transferId,
    OfferedTransfer transfer,
    int bytesSent,
  ) {
    transfer.bytesSent = bytesSent;
    final isLastByte = bytesSent == transfer.totalBytes;
    if (!isLastByte &&
        transfer.sinceLastProgressReport.elapsed < _progressReportInterval) {
      return;
    }
    transfer.sinceLastProgressReport.reset();
    _emit(
      transferId,
      OutgoingTransferSending(
        bytesSent: bytesSent,
        totalBytes: transfer.totalBytes,
      ),
    );
  }

  void _armStallTimer(String transferId, OfferedTransfer transfer) {
    transfer.stallTimer?.cancel();
    if (transfer.isEnded) return;
    transfer.stallTimer = Timer(
      resumeWindow,
      () => _end(transferId, TransferFailure.unreachable, notifyReceiver: true),
    );
  }

  void _complete(String transferId, OfferedTransfer transfer) {
    _transfers.remove(transferId);
    transfer.isEnded = true;
    transfer.stallTimer?.cancel();
    _emit(transferId, const OutgoingTransferCompleted());
  }

  void _end(
    String transferId,
    TransferFailure reason, {
    required bool notifyReceiver,
  }) {
    final transfer = _transfers.remove(transferId);
    if (transfer == null) return;
    transfer.isEnded = true;
    transfer.decisionTimer.cancel();
    transfer.stallTimer?.cancel();
    if (notifyReceiver) {
      hub.send(transfer.deviceId, TransferDecisionMessage.cancel(transferId));
    }
    _emit(transferId, OutgoingTransferFailed(reason));
  }

  /// A lost phone can't answer an offer, so those end; accepted transfers
  /// wait for it to come back and ask for the rest.
  void _handleDisconnect(String deviceId) {
    final toDevice = [
      for (final MapEntry(:key, :value) in _transfers.entries)
        if (value.deviceId == deviceId) (key, value),
    ];
    for (final (transferId, transfer) in toDevice) {
      if (!transfer.isAccepted) {
        _end(transferId, TransferFailure.unreachable, notifyReceiver: false);
        continue;
      }
      // Downloads still writing to the dead connection stop counting.
      transfer.currentServes.clear();
      _emit(transferId, const OutgoingTransferReconnecting());
      _armStallTimer(transferId, transfer);
    }
  }

  // A download still in flight may report after close(); drop those events.
  void _emit(String transferId, OutgoingTransferUpdate update) {
    if (_events.isClosed) return;
    _events.add((transferId: transferId, update: update));
  }
}
