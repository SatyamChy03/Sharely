import 'dart:async';
import 'dart:io';

import 'package:sharely_core/src/pairing/device_endpoint.dart';
import 'package:sharely_core/src/protocol/protocol_message.dart';
import 'package:sharely_core/src/security/file_safety_exception.dart';
import 'package:sharely_core/src/transfer/control_connection.dart';
import 'package:sharely_core/src/transfer/guarded_stream.dart';
import 'package:sharely_core/src/transfer/incoming_file_writer.dart';
import 'package:sharely_core/src/transfer/incoming_transfer_event.dart';
import 'package:sharely_core/src/transfer/peer_link.dart';
import 'package:sharely_core/src/transfer/resume_settings.dart';
import 'package:sharely_core/src/transfer/transfer_exception.dart';
import 'package:sharely_core/src/transfer/transfer_paths.dart';
import 'package:sharely_core/src/transfer/upload_checksum.dart';

const _progressReportInterval = Duration(milliseconds: 100);

/// Phone side of one receive: accept the laptop's offer, then download and
/// verify each file.
///
/// A download cut off by bad Wi-Fi keeps its bytes and continues from there
/// once the connection is back.
///
/// Watch [events]; [done] completes when the transfer is over, either way.
class IncomingDownload {
  new _({
    required this.offer,
    required this._link,
    required this._authHeaders,
    required this._saveDirectory,
    required this._reconnect,
    required this._resumeWindow,
    required this._retryDelay,
    required this._dataIdleTimeout,
  });

  /// Accepts [offer] and starts downloading from [endpoint] right away.
  ///
  /// Without [reconnect] a download survives a broken data connection but
  /// not the loss of [connection] itself.
  factory start({
    required OfferMessage offer,
    required ControlConnection connection,
    required DeviceEndpoint endpoint,
    required Map<String, String> authHeaders,
    required Future<Directory> Function() saveDirectory,
    PeerReconnect? reconnect,
    Duration resumeWindow = defaultResumeWindow,
    Duration retryDelay = const Duration(seconds: 1),
    Duration dataIdleTimeout = defaultDataIdleTimeout,
  }) {
    final download = IncomingDownload._(
      offer: offer,
      link: (connection: connection, endpoint: endpoint),
      authHeaders: authHeaders,
      saveDirectory: saveDirectory,
      reconnect: reconnect,
      resumeWindow: resumeWindow,
      retryDelay: retryDelay,
      dataIdleTimeout: dataIdleTimeout,
    );
    // Deferred one turn so callers can listen to [events] before the first.
    download._done = Future(download._run);
    return download;
  }

  final OfferMessage offer;
  final Map<String, String> _authHeaders;
  final Future<Directory> Function() _saveDirectory;
  final PeerReconnect? _reconnect;
  final Duration _resumeWindow;
  final Duration _retryDelay;
  final Duration _dataIdleTimeout;

  final _events = StreamController<IncomingTransferEvent>.broadcast();
  final _stopped = Completer<TransferFailure>();
  final _sinceLastProgress = Stopwatch()..start();
  final _sinceLastByte = Stopwatch();
  late final Future<void> _done;
  PeerLink _link;
  StreamSubscription<ProtocolMessage>? _messages;
  HttpClient? _activeClient;
  Completer<void>? _attemptBroken;
  PartialIncomingFile? _unfinished;
  TransferFailure? _stopReason;
  bool _wasStoppedByLaptop = false;
  int _bytesReceived = 0;

  Stream<IncomingTransferEvent> get events => _events.stream;

  Future<void> get done => _done;

  String get _transferId => offer.transferId;

  /// Stops the download; files already verified stay saved.
  void cancel() => _stop(TransferFailure.cancelled);

  Future<void> _run() async {
    _follow(_link.connection);
    try {
      final savedFiles = await _downloadEveryFile();
      await _confirmToLaptop();
      _emit(IncomingTransferCompleted(_transferId, savedFiles: savedFiles));
    } on TransferException catch (error) {
      await _fail(_stopReason ?? error.failure);
    } on FileSystemException {
      await _fail(_stopReason ?? TransferFailure.refused);
    } on FileSafetyException {
      await _fail(TransferFailure.refused);
    } finally {
      await _messages?.cancel();
      await _events.close();
    }
  }

  /// Listens to [connection], the first one or the one after a reconnect.
  void _follow(ControlConnection connection) {
    unawaited(_messages?.cancel());
    _messages = connection.messages.listen(_handleMessage);
    unawaited(
      connection.done.then((_) {
        // The data connection is very likely dead too; don't wait on it.
        if (identical(connection, _link.connection)) _breakAttempt();
      }),
    );
  }

  Future<List<File>> _downloadEveryFile() async {
    _throwIfStopped();
    _link.connection.send(TransferDecisionMessage.accept(_transferId));
    final directory = await _saveDirectory();
    await directory.create(recursive: true);
    final savedFiles = <File>[];
    for (var index = 0; index < offer.files.length; index++) {
      savedFiles.add(await _downloadFile(index, directory));
    }
    _throwIfStopped();
    return List.unmodifiable(savedFiles);
  }

  Future<File> _downloadFile(int index, Directory directory) async {
    _throwIfStopped();
    final partial = await PartialIncomingFile.create(
      directory,
      offer.files[index],
    );
    _unfinished = partial;
    _sinceLastByte
      ..reset()
      ..start();
    while (!await _downloadRest(index, partial)) {
      _emit(IncomingTransferInterrupted(_transferId));
      await _waitToRetry();
    }
    _unfinished = null;
    return partial.file;
  }

  /// Fetches what [partial] still lacks. Returns false when the download
  /// broke off and is worth resuming.
  Future<bool> _downloadRest(int index, PartialIncomingFile partial) async {
    _throwIfStopped();
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 8)
      // The declared length must describe the bytes exactly as they arrive.
      ..autoUncompress = false;
    final broken = Completer<void>();
    _activeClient = client;
    _attemptBroken = broken;
    try {
      // Raced, because closing a client does not always wake a request that
      // is still connecting.
      final response = await Future.any([
        _requestRest(client, index, partial.bytesWritten),
        broken.future.then<HttpClientResponse>(
          (_) => throw const TransferInterrupted(),
        ),
      ]);
      if (!_isRestOffered(response, partial)) {
        await response.drain<void>();
        return false;
      }
      await partial.append(
        guardStream(
          response,
          interrupted: broken.future,
          idleTimeout: _dataIdleTimeout,
        ),
        isCancelled: () => _stopReason != null,
        onBytesWritten: _recordProgress,
      );
      return true;
    } on TransferInterrupted {
      _throwIfStopped();
      return false;
    } on FileSystemException {
      rethrow;
    } on IOException {
      _throwIfStopped();
      return false;
    } finally {
      _activeClient = null;
      _attemptBroken = null;
      client.close(force: true);
    }
  }

  Future<HttpClientResponse> _requestRest(
    HttpClient client,
    int index,
    int offset,
  ) async {
    final request = await client.getUrl(
      _link.endpoint.httpUri(transferFilePath(_transferId, index)),
    );
    _authHeaders.forEach(request.headers.set);
    request.headers.set(resumeOffsetHeader, offset);
    return await request.close();
  }

  bool _isRestOffered(
    HttpClientResponse response,
    PartialIncomingFile partial,
  ) {
    // The laptop gave the transfer up while we were away.
    if (response.statusCode == HttpStatus.notFound) {
      throw const TransferException(TransferFailure.unreachable);
    }
    if (response.statusCode != HttpStatus.ok) return false;
    final restBytes = partial.expected.sizeBytes - partial.bytesWritten;
    if (response.contentLength != restBytes + uploadChecksumBytes) {
      throw const TransferException(TransferFailure.corrupted);
    }
    return true;
  }

  /// Pauses before the next attempt, restoring the link if it was lost.
  /// Gives up once nothing has arrived for the resume window.
  Future<void> _waitToRetry() async {
    _throwIfStopped();
    if (_sinceLastByte.elapsed > _resumeWindow) {
      throw const TransferException(TransferFailure.unreachable);
    }
    await Future.any([Future<void>.delayed(_retryDelay), _stopped.future]);
    _throwIfStopped();
    if (_link.connection.isOpen) return;
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

  /// Tells the laptop every file was verified, not merely transferred. The
  /// files are safe either way, so a link that stays down is not a failure.
  Future<void> _confirmToLaptop() async {
    if (!_link.connection.isOpen) {
      final link = await awaitNewLink(
        _reconnect,
        timeLeft: _resumeWindow,
        abandoned: _stopped.future,
      );
      if (link != null) _link = link;
    }
    _link.connection.send(
      ProgressMessage(transferId: _transferId, bytes: offer.totalBytes),
    );
  }

  void _handleMessage(ProtocolMessage message) {
    if (message is! TransferDecisionMessage ||
        message.transferId != _transferId ||
        message.type != MessageType.cancel) {
      return;
    }
    _wasStoppedByLaptop = true;
    _stop(TransferFailure.cancelled);
  }

  void _stop(TransferFailure reason) {
    if (_stopReason != null) return;
    _stopReason = reason;
    _stopped.complete(reason);
    _breakAttempt();
  }

  void _breakAttempt() {
    final broken = _attemptBroken;
    if (broken != null && !broken.isCompleted) broken.complete();
    _activeClient?.close(force: true);
  }

  Future<void> _fail(TransferFailure reason) async {
    await _unfinished?.discard();
    if (!_wasStoppedByLaptop) {
      _link.connection.send(TransferDecisionMessage.cancel(_transferId));
    }
    _emit(IncomingTransferEnded(_transferId, reason: reason));
  }

  void _throwIfStopped() {
    final reason = _stopReason;
    if (reason != null) throw TransferException(reason);
  }

  void _recordProgress(int byteCount) {
    _bytesReceived += byteCount;
    _sinceLastByte.reset();
    final isLastByte = _bytesReceived == offer.totalBytes;
    if (!isLastByte && _sinceLastProgress.elapsed < _progressReportInterval) {
      return;
    }
    _sinceLastProgress.reset();
    _emit(
      IncomingTransferProgressed(
        _transferId,
        bytesReceived: _bytesReceived,
        totalBytes: offer.totalBytes,
      ),
    );
  }

  void _emit(IncomingTransferEvent event) {
    if (!_events.isClosed) _events.add(event);
  }
}
