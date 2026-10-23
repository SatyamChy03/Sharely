import 'dart:async';
import 'dart:io';

import 'package:sharely_core/src/pairing/device_endpoint.dart';
import 'package:sharely_core/src/protocol/message_codec.dart';
import 'package:sharely_core/src/protocol/protocol_exception.dart';
import 'package:sharely_core/src/protocol/protocol_message.dart';
import 'package:sharely_core/src/security/secure_id.dart';
import 'package:sharely_core/src/transfer/link_liveness.dart';
import 'package:sharely_core/src/transfer/transfer_exception.dart';
import 'package:sharely_core/src/transfer/transfer_paths.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/status.dart' as close_status;
import 'package:web_socket_channel/web_socket_channel.dart';

/// More messages than this in one [controlFloodWindow] is not a person
/// using the app; real use is a handful of offers, answers and notes.
const maxControlMessagesPerWindow = 120;
const controlFloodWindow = Duration(seconds: 10);

/// Sent when the peer stopped answering. In the app range, like the one
/// below, since 1001 "going away" is reserved for the socket itself.
const silentPeerCloseCode = 4001;

/// Sent when a peer breaks the protocol. Apps may only use 1000 or 3000-4999,
/// so this mirrors the standard 1008 "policy violation" in the app range.
const protocolViolationCloseCode = 4008;

/// One end of the control WebSocket: validated messages in, messages out.
///
/// A frame that fails validation closes the connection; it is never trusted.
class ControlConnection {
  new(
    this._channel, {
    LivenessClock? clock,
    Duration? checkEvery,
    Duration allowedSilence = controlSilenceLimit,
  }) {
    _liveness = LinkLiveness(
      sendPing: () => send(HeartbeatMessage.ping(generateSecureId())),
      closeAsDead: () => unawaited(close(silentPeerCloseCode)),
      clock: clock,
      checkEvery: checkEvery ?? controlPingInterval,
      allowedSilence: allowedSilence,
    );
    _channel.stream.listen(
      _handleFrame,
      onDone: _markClosed,
      onError: (Object _) => _markClosed(),
      cancelOnError: true,
    );
  }

  final WebSocketChannel _channel;
  final _messages = StreamController<ProtocolMessage>.broadcast();
  final _closed = Completer<void>();
  final _awaitedAnswers = <String, Completer<void>>{};
  final _sinceWindowStart = Stopwatch()..start();
  int _messagesInWindow = 0;
  late final LinkLiveness _liveness;

  /// Opens an authenticated control channel to a laptop's server.
  ///
  /// Throws [TransferException] with [TransferFailure.unreachable] on failure.
  static Future<ControlConnection> connect(
    DeviceEndpoint endpoint, {
    required Map<String, String> authHeaders,
    Duration timeout = const Duration(seconds: 8),
    LivenessClock? clock,
    Duration? checkEvery,
  }) async {
    final client = endpoint.createHttpClient(connectionTimeout: timeout);
    final channel = IOWebSocketChannel.connect(
      endpoint.webSocketUri(controlChannelPath),
      headers: authHeaders,
      connectTimeout: timeout,
      customClient: client,
    );
    try {
      await channel.ready;
    } on WebSocketChannelException {
      throw const TransferException(TransferFailure.unreachable);
    } on IOException {
      throw const TransferException(TransferFailure.unreachable);
    } on TimeoutException {
      throw const TransferException(TransferFailure.unreachable);
    } finally {
      // An upgraded socket lives on by itself; the client is done either way.
      client.close();
    }
    return ControlConnection(channel, clock: clock, checkEvery: checkEvery);
  }

  Stream<ProtocolMessage> get messages => _messages.stream;

  Future<void> get done => _closed.future;

  bool get isOpen => !_closed.isCompleted;

  /// How long the peer may stay silent before the link counts as lost.
  Duration get allowedSilence => _liveness.allowedSilence;

  set allowedSilence(Duration limit) => _liveness.allowedSilence = limit;

  /// Asks the peer to answer right now. False when it does not within
  /// [timeout]: the link is dead, even if the socket has not noticed.
  Future<bool> isAlive({Duration timeout = const Duration(seconds: 2)}) async {
    if (!isOpen) return false;
    final id = generateSecureId();
    final answered = _awaitedAnswers[id] = Completer<void>();
    send(HeartbeatMessage.ping(id));
    try {
      await answered.future.timeout(timeout);
      return isOpen;
    } on TimeoutException {
      return false;
    } finally {
      _awaitedAnswers.remove(id);
    }
  }

  void send(ProtocolMessage message) {
    if (!isOpen) return;
    _channel.sink.add(MessageCodec.encode(message));
  }

  Future<void> close([int code = close_status.normalClosure]) async {
    _markClosed();
    await _channel.sink.close(code);
  }

  void _handleFrame(Object? frame) {
    if (frame is! String || _isFlooding()) return _rejectPeer();
    _liveness.recordHeard();
    final ProtocolMessage message;
    try {
      message = MessageCodec.decode(frame);
    } on ProtocolException {
      return _rejectPeer();
    }
    // Heartbeats are answered here and never reach the app.
    switch (message) {
      case HeartbeatMessage(type: MessageType.ping, :final id):
        send(HeartbeatMessage.pong(id));
      case HeartbeatMessage(:final id):
        final answered = _awaitedAnswers[id];
        if (answered != null && !answered.isCompleted) answered.complete();
      default:
        _messages.add(message);
    }
  }

  // A paired device can still be compromised; it must not be able to keep
  // this one busy parsing or bury the screen in notes.
  bool _isFlooding() {
    if (_sinceWindowStart.elapsed > controlFloodWindow) {
      _sinceWindowStart.reset();
      _messagesInWindow = 0;
    }
    _messagesInWindow++;
    return _messagesInWindow > maxControlMessagesPerWindow;
  }

  void _rejectPeer() => unawaited(close(protocolViolationCloseCode));

  void _markClosed() {
    if (_closed.isCompleted) return;
    _liveness.stop();
    _closed.complete();
    unawaited(_messages.close());
  }
}
