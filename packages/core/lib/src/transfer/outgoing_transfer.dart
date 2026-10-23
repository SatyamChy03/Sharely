import 'dart:async';
import 'dart:io';

import 'package:sharely_core/src/pairing/device_endpoint.dart';
import 'package:sharely_core/src/protocol/protocol_message.dart';
import 'package:sharely_core/src/security/secure_id.dart';
import 'package:sharely_core/src/transfer/checksummed_file_stream.dart';
import 'package:sharely_core/src/transfer/control_connection.dart';
import 'package:sharely_core/src/transfer/outgoing_file.dart';
import 'package:sharely_core/src/transfer/outgoing_transfer_update.dart';
import 'package:sharely_core/src/transfer/parallel_settings.dart';
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
    required this._parallelFiles,
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
    int parallelFiles = defaultParallelFiles,
  }) {
    final transfer = OutgoingTransfer._(
      files: List.unmodifiable(files),
      link: (connection: connection, endpoint: endpoint),
      authHeaders: authHeaders,
      decisionTimeout: decisionTimeout,
      reconnect: reconnect,
      resumeWindow: resumeWindow,
      retryDelay: retryDelay,
      parallelFiles: parallelFiles.clamp(1, maxParallelFilesPerTransfer),
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
  final int _parallelFiles;

  final _updates = StreamController<OutgoingTransferUpdate>.broadcast();
  final _accepted = Completer<void>();
  final _stopped = Completer<TransferFailure>();
  final _sinceLastProgress = Stopwatch();
  final _sinceLastByte = Stopwatch();
  late final Future<void> _done;
  PeerLink _link;
  StreamSubscription<ProtocolMessage>? _messages;
  final _activeUploads = <HttpClientRequest>{};
  final _bytesSentByFile = <int, int>{};
  Future<void>? _linkBeingRestored;
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
      await _uploadEveryFile();
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
        _abortUploads();
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

  /// Sends a few files at a time, each on its own connection. The first
  /// failure stops the others, and is the one reported.
  Future<void> _uploadEveryFile() async {
    var nextIndex = 0;
    (Object, StackTrace)? firstFailure;
    Future<void> uploadUntilNoneLeft() async {
      try {
        while (nextIndex < files.length) {
          await _uploadFileWithResume(nextIndex++);
        }
      } on Object catch (error, stackTrace) {
        if (firstFailure != null) return;
        firstFailure = (error, stackTrace);
        if (error is TransferException) {
          _stop(error.failure);
        } else {
          cancel();
        }
      }
    }

    _sinceLastByte
      ..reset()
      ..start();
    await Future.wait([
      for (var worker = 0; worker < _parallelFiles; worker++)
        uploadUntilNoneLeft(),
    ]);
    if (firstFailure case (final error, final stackTrace)?) {
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<void> _uploadFileWithResume(int index) async {
    var offset = 0;
    while (!await _uploadFile(index, offset)) {
      _emit(const OutgoingTransferReconnecting());
      final held = await _findResumePoint(index);
      // The laptop saved the file but its answer never reached us.
      if (held.isSaved) return;
      offset = held.bytes;
    }
  }

  /// Sends file [index] from [offset]. Returns false when the upload broke
  /// off and is worth resuming.
  Future<bool> _uploadFile(int index, int offset) async {
    _throwIfStopped();
    final file = files[index];
    final client = _link.endpoint.createHttpClient();
    HttpClientRequest? upload;
    try {
      final request = await client.putUrl(
        _link.endpoint.httpsUri(transferFilePath(transferId, index)),
      );
      upload = request;
      _activeUploads.add(request);
      _throwIfStopped();
      _authHeaders.forEach(request.headers.set);
      request.headers
        ..contentType = ContentType.binary
        ..set(resumeOffsetHeader, offset);
      request.contentLength = file.sizeBytes - offset + uploadChecksumBytes;
      await request.addStream(_readFrom(index, offset));
      final response = await request.close();
      await response.drain<void>();
      return _isUploadSaved(response.statusCode);
    } on FileSystemException {
      rethrow;
    } on IOException {
      _throwIfStopped();
      return false;
    } finally {
      _activeUploads.remove(upload);
      client.close(force: true);
    }
  }

  Stream<List<int>> _readFrom(int index, int offset) {
    // A resumed file counts again from the byte the laptop already holds.
    _bytesSentByFile[index] = offset;
    return readFileWithChecksum(
      files[index],
      offset: offset,
      shouldStop: () => _stopReason != null,
      onBytesYielded: (byteCount) {
        _bytesSentByFile.update(index, (sent) => sent + byteCount);
        _sinceLastByte.reset();
        _reportSending();
      },
    );
  }

  void _abortUploads() {
    for (final upload in [..._activeUploads]) {
      upload.abort();
    }
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
        _link.endpoint,
        transferOffsetPath(transferId, index),
        authHeaders: _authHeaders,
        fileSizeBytes: files[index].sizeBytes,
      );
      if (held != null) return held;
    }
  }

  // Every paused upload waits on the same reconnect, not one each.
  Future<void> _restoreLink() => _linkBeingRestored ??= _awaitNewLink()
      .whenComplete(() => _linkBeingRestored = null);

  Future<void> _awaitNewLink() async {
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
    _abortUploads();
  }

  void _throwIfStopped() {
    final reason = _stopReason;
    if (reason != null) throw TransferException(reason);
  }

  void _reportSending() {
    final bytesSent = _bytesSentByFile.values.fold(
      0,
      (sum, sent) => sum + sent,
    );
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
