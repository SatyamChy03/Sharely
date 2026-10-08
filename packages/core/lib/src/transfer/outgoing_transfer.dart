import 'dart:async';
import 'dart:io';

import 'package:sharely_core/src/pairing/device_endpoint.dart';
import 'package:sharely_core/src/protocol/protocol_message.dart';
import 'package:sharely_core/src/security/secure_id.dart';
import 'package:sharely_core/src/transfer/checksummed_file_stream.dart';
import 'package:sharely_core/src/transfer/control_connection.dart';
import 'package:sharely_core/src/transfer/outgoing_file.dart';
import 'package:sharely_core/src/transfer/outgoing_transfer_update.dart';
import 'package:sharely_core/src/transfer/peer_link.dart';
import 'package:sharely_core/src/transfer/resume_point.dart';
import 'package:sharely_core/src/transfer/resume_settings.dart';
import 'package:sharely_core/src/transfer/transfer_exception.dart';
import 'package:sharely_core/src/transfer/transfer_paths.dart';
import 'package:sharely_core/src/transfer/upload_checksum.dart';

const _progressReportInterval = Duration(milliseconds: 100);

/// Phone side of one send: offer, wait for accept, then upload.
///
/// An upload cut off by bad Wi-Fi continues from the byte the laptop last
/// saved, once the connection is back, instead of starting over.
///
/// Watch [updates], await [done] (throws [TransferException]), or [cancel].
class OutgoingTransfer {
  new _({
    required this.files,
    required this._link,
    required this._authHeaders,
    required this._decisionTimeout,
    required this._reconnect,
    required this._resumeWindow,
    required this._retryDelay,
  }) : transferId = generateSecureId();

  /// Starts sending [files] to the laptop at [endpoint] right away.
  ///
  /// Without [reconnect] a send survives a broken upload but not the loss
  /// of [connection] itself.
  factory start({
    required List<OutgoingFile> files,
    required ControlConnection connection,
    required DeviceEndpoint endpoint,
    required Map<String, String> authHeaders,
    Duration decisionTimeout = const Duration(minutes: 2),
    PeerReconnect? reconnect,
    Duration resumeWindow = defaultResumeWindow,
    Duration retryDelay = const Duration(seconds: 1),
  }) {
    final transfer = OutgoingTransfer._(
      files: List.unmodifiable(files),
      link: (connection: connection, endpoint: endpoint),
      authHeaders: authHeaders,
      decisionTimeout: decisionTimeout,
      reconnect: reconnect,
      resumeWindow: resumeWindow,
      retryDelay: retryDelay,
    );
    // Deferred one turn so callers can listen to [updates] before the first.
    transfer._done = Future(transfer._run);
    return transfer;
  }

  final String transferId;
  final List<OutgoingFile> files;
  final Map<String, String> _authHeaders;
  final Duration _decisionTimeout;
  final PeerReconnect? _reconnect;
  final Duration _resumeWindow;
  final Duration _retryDelay;

  final _updates = StreamController<OutgoingTransferUpdate>.broadcast();
  final _accepted = Completer<void>();
  final _stopped = Completer<TransferFailure>();
  final _sinceLastProgress = Stopwatch();
  final _sinceLastByte = Stopwatch();
  late final Future<void> _done;
  PeerLink _link;
  StreamSubscription<ProtocolMessage>? _messages;
  HttpClientRequest? _activeUpload;
  TransferFailure? _stopReason;

  Stream<OutgoingTransferUpdate> get updates => _updates.stream;

  Future<void> get done => _done;

  int get totalBytes => files.fold(0, (sum, file) => sum + file.sizeBytes);

  /// Stops the transfer and tells the laptop, at any stage.
  void cancel() {
    if (_stopped.isCompleted) return;
    _link.connection.send(TransferDecisionMessage.cancel(transferId));
    _stop(TransferFailure.cancelled);
  }

  Future<void> _run() async {
    _follow(_link.connection);
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
        await _uploadFileWithResume(index, bytesBefore);
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
      await _messages?.cancel();
      await _updates.close();
    }
  }

  /// Listens to [connection], the first one or the one after a reconnect.
  void _follow(ControlConnection connection) {
    unawaited(_messages?.cancel());
    _messages = connection.messages.listen(_handleMessage);
    unawaited(
      connection.done.then((_) {
        if (!identical(connection, _link.connection)) return;
        // An unanswered offer dies with its connection; an accepted one is
        // only paused, so just break the stuck upload loose.
        if (!_accepted.isCompleted) return _stop(TransferFailure.unreachable);
        _activeUpload?.abort();
      }),
    );
  }

  Future<void> _offerAndAwaitAcceptance(List<OfferedFile> offeredFiles) async {
    _throwIfStopped();
    final connection = _link.connection
      ..send(OfferMessage(transferId: transferId, files: offeredFiles));
    _emit(const OutgoingTransferAwaitingAcceptance());
    final stopped = _stopped.future.then<void>(
      (reason) => throw TransferException(reason),
    );
    await Future.any([_accepted.future, stopped]).timeout(
      _decisionTimeout,
      onTimeout: () {
        connection.send(TransferDecisionMessage.cancel(transferId));
        _stop(TransferFailure.timedOut);
        throw const TransferException(TransferFailure.timedOut);
      },
    );
  }

  Future<void> _uploadFileWithResume(int index, int bytesBefore) async {
    var offset = 0;
    _sinceLastByte
      ..reset()
      ..start();
    while (!await _uploadFile(index, bytesBefore, offset)) {
      _emit(const OutgoingTransferReconnecting());
      final held = await _findResumePoint(index);
      // The laptop saved the file but its answer never reached us.
      if (held.isSaved) return;
      offset = held.bytes;
    }
  }

  /// Sends file [index] from [offset]. Returns false when the upload broke
  /// off and is worth resuming.
  Future<bool> _uploadFile(int index, int bytesBefore, int offset) async {
    _throwIfStopped();
    final file = files[index];
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final request = await client.putUrl(
        _link.endpoint.httpUri(transferFilePath(transferId, index)),
      );
      _activeUpload = request;
      _throwIfStopped();
      _authHeaders.forEach(request.headers.set);
      request.headers
        ..contentType = ContentType.binary
        ..set(resumeOffsetHeader, offset);
      request.contentLength = file.sizeBytes - offset + uploadChecksumBytes;
      await request.addStream(_readFrom(file, offset, bytesBefore));
      final response = await request.close();
      await response.drain<void>();
      return _isUploadSaved(response.statusCode);
    } on FileSystemException {
      rethrow;
    } on IOException {
      _throwIfStopped();
      return false;
    } finally {
      _activeUpload = null;
      client.close(force: true);
    }
  }

  Stream<List<int>> _readFrom(OutgoingFile file, int offset, int bytesBefore) {
    var bytesSent = bytesBefore + offset;
    return readFileWithChecksum(
      file,
      offset: offset,
      shouldStop: () => _stopReason != null,
      onBytesYielded: (byteCount) {
        bytesSent += byteCount;
        _sinceLastByte.reset();
        _reportSending(bytesSent);
      },
    );
  }

  bool _isUploadSaved(int statusCode) {
    if (statusCode == HttpStatus.noContent) return true;
    _throwIfStopped();
    return switch (statusCode) {
      // The laptop holds a different amount than we assumed; ask again.
      HttpStatus.conflict || HttpStatus.serviceUnavailable => false,
      HttpStatus.unprocessableEntity => throw const TransferException(
        TransferFailure.corrupted,
      ),
      _ => throw const TransferException(TransferFailure.refused),
    };
  }

  /// Waits for the laptop to be reachable again and asks how much of file
  /// [index] it holds. Gives up once nothing has moved for the resume window.
  Future<ResumePoint> _findResumePoint(int index) async {
    while (true) {
      _throwIfStopped();
      if (_sinceLastByte.elapsed > _resumeWindow) {
        throw const TransferException(TransferFailure.unreachable);
      }
      await Future.any([Future<void>.delayed(_retryDelay), _stopped.future]);
      _throwIfStopped();
      if (!_link.connection.isOpen) {
        await _restoreLink();
        continue;
      }
      final held = await askResumePoint(
        _link.endpoint.httpUri(transferOffsetPath(transferId, index)),
        authHeaders: _authHeaders,
        fileSizeBytes: files[index].sizeBytes,
      );
      if (held != null) return held;
    }
  }

  Future<void> _restoreLink() async {
    final link = await awaitNewLink(
      _reconnect,
      timeLeft: _resumeWindow - _sinceLastByte.elapsed,
      abandoned: _stopped.future,
    );
    _throwIfStopped();
    if (link == null) {
      throw const TransferException(TransferFailure.unreachable);
    }
    _link = link;
    _follow(link.connection);
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
