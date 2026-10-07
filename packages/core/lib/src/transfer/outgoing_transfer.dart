import 'dart:async';
import 'dart:io';

import 'package:sharely_core/src/pairing/device_endpoint.dart';
import 'package:sharely_core/src/protocol/protocol_message.dart';
import 'package:sharely_core/src/security/secure_id.dart';
import 'package:sharely_core/src/transfer/control_connection.dart';
import 'package:sharely_core/src/transfer/outgoing_file.dart';
import 'package:sharely_core/src/transfer/outgoing_transfer_update.dart';
import 'package:sharely_core/src/transfer/transfer_exception.dart';
import 'package:sharely_core/src/transfer/transfer_paths.dart';
import 'package:sharely_core/src/transfer/upload_checksum.dart';
import 'package:sharely_core/src/transfer/xxh64_accumulator.dart';

const _progressReportInterval = Duration(milliseconds: 100);

/// Phone side of one send: offer, wait for accept, then upload.
///
/// Watch [updates], await [done] (throws [TransferException]), or [cancel].
class OutgoingTransfer {
  new _({
    required this.files,
    required this._connection,
    required this._endpoint,
    required this._authHeaders,
    required this._decisionTimeout,
  }) : transferId = generateSecureId();

  /// Starts sending [files] to the laptop at [endpoint] right away.
  factory start({
    required List<OutgoingFile> files,
    required ControlConnection connection,
    required DeviceEndpoint endpoint,
    required Map<String, String> authHeaders,
    Duration decisionTimeout = const Duration(minutes: 2),
  }) {
    final transfer = OutgoingTransfer._(
      files: List.unmodifiable(files),
      connection: connection,
      endpoint: endpoint,
      authHeaders: authHeaders,
      decisionTimeout: decisionTimeout,
    );
    // Deferred one turn so callers can listen to [updates] before the first.
    transfer._done = Future(transfer._run);
    return transfer;
  }

  final String transferId;
  final List<OutgoingFile> files;
  final ControlConnection _connection;
  final DeviceEndpoint _endpoint;
  final Map<String, String> _authHeaders;
  final Duration _decisionTimeout;

  final _updates = StreamController<OutgoingTransferUpdate>.broadcast();
  final _accepted = Completer<void>();
  final _stopped = Completer<TransferFailure>();
  final _sinceLastProgress = Stopwatch();
  late final Future<void> _done;
  HttpClientRequest? _activeUpload;
  TransferFailure? _stopReason;

  Stream<OutgoingTransferUpdate> get updates => _updates.stream;

  Future<void> get done => _done;

  int get totalBytes => files.fold(0, (sum, file) => sum + file.sizeBytes);

  /// Stops the transfer and tells the laptop, at any stage.
  void cancel() {
    if (_stopped.isCompleted) return;
    _connection.send(TransferDecisionMessage.cancel(transferId));
    _stop(TransferFailure.cancelled);
  }

  Future<void> _run() async {
    final subscription = _connection.messages.listen(_handleMessage);
    unawaited(_connection.done.then((_) => _stop(TransferFailure.unreachable)));
    try {
      await _offerAndAwaitAcceptance([
        for (final file in files)
          OfferedFile(
            name: file.name,
            sizeBytes: file.sizeBytes,
            mimeType: file.mimeType,
          ),
      ]);
      var bytesBefore = 0;
      for (var index = 0; index < files.length; index++) {
        await _uploadFile(index, bytesBefore);
        bytesBefore += files[index].sizeBytes;
      }
      _emit(const OutgoingTransferCompleted());
    } on TransferException catch (error) {
      _emit(OutgoingTransferFailed(error.failure));
      rethrow;
    } on FileSystemException {
      cancel();
      _emit(const OutgoingTransferFailed(TransferFailure.unreadableFile));
      throw const TransferException(TransferFailure.unreadableFile);
    } finally {
      await subscription.cancel();
      await _updates.close();
    }
  }

  Future<void> _offerAndAwaitAcceptance(List<OfferedFile> offeredFiles) async {
    _throwIfStopped();
    _connection.send(OfferMessage(transferId: transferId, files: offeredFiles));
    _emit(const OutgoingTransferAwaitingAcceptance());
    final stopped = _stopped.future.then<void>(
      (reason) => throw TransferException(reason),
    );
    await Future.any([_accepted.future, stopped]).timeout(
      _decisionTimeout,
      onTimeout: () {
        _connection.send(TransferDecisionMessage.cancel(transferId));
        _stop(TransferFailure.timedOut);
        throw const TransferException(TransferFailure.timedOut);
      },
    );
  }

  Future<void> _uploadFile(int index, int bytesBefore) async {
    _throwIfStopped();
    final file = files[index];
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final request = await client.putUrl(
        _endpoint.httpUri(transferFilePath(transferId, index)),
      );
      _activeUpload = request;
      _throwIfStopped();
      _authHeaders.forEach(request.headers.set);
      request.headers.contentType = ContentType.binary;
      request.contentLength = file.sizeBytes + uploadChecksumBytes;
      await _streamFileWithChecksum(request, file, bytesBefore);
      final response = await request.close();
      await response.drain<void>();
      _checkUploadAccepted(response.statusCode);
    } on FileSystemException {
      rethrow;
    } on IOException {
      _throwIfStopped();
      throw const TransferException(TransferFailure.unreachable);
    } finally {
      _activeUpload = null;
      client.close(force: true);
    }
  }

  /// Hashes while sending, so the file is read from disk exactly once.
  Future<void> _streamFileWithChecksum(
    HttpClientRequest request,
    OutgoingFile file,
    int bytesBefore,
  ) async {
    final hasher = Xxh64Accumulator();
    var bytesSent = 0;
    await request.addStream(
      file.openRead().map((chunk) {
        bytesSent += chunk.length;
        if (bytesSent > file.sizeBytes) {
          throw FileSystemException('Grew while sending', file.name);
        }
        hasher.add(chunk);
        _reportSending(bytesBefore + bytesSent);
        return chunk;
      }),
    );
    if (bytesSent != file.sizeBytes) {
      throw FileSystemException('Shrank while sending', file.name);
    }
    request.add(encodeUploadChecksum(hasher.finish()));
  }

  void _checkUploadAccepted(int statusCode) {
    if (statusCode == HttpStatus.noContent) return;
    _throwIfStopped();
    throw TransferException(
      statusCode == HttpStatus.unprocessableEntity
          ? TransferFailure.corrupted
          : TransferFailure.refused,
    );
  }

  void _handleMessage(ProtocolMessage message) {
    if (message is! TransferDecisionMessage ||
        message.transferId != transferId) {
      return;
    }
    if (message.type == MessageType.accept) {
      if (!_accepted.isCompleted) _accepted.complete();
    } else if (message.type == MessageType.reject) {
      _stop(TransferFailure.rejected);
    } else if (message.type == MessageType.cancel) {
      _stop(TransferFailure.cancelled);
    }
  }

  void _stop(TransferFailure reason) {
    if (_stopped.isCompleted) return;
    _stopReason = reason;
    _stopped.complete(reason);
    _activeUpload?.abort();
  }

  void _throwIfStopped() {
    final reason = _stopReason;
    if (reason != null) throw TransferException(reason);
  }

  void _reportSending(int bytesSent) {
    final isLastByte = bytesSent == totalBytes;
    if (!isLastByte &&
        _sinceLastProgress.isRunning &&
        _sinceLastProgress.elapsed < _progressReportInterval) {
      return;
    }
    _sinceLastProgress
      ..reset()
      ..start();
    _emit(
      OutgoingTransferSending(bytesSent: bytesSent, totalBytes: totalBytes),
    );
  }

  void _emit(OutgoingTransferUpdate update) {
    if (!_updates.isClosed) _updates.add(update);
  }
}
