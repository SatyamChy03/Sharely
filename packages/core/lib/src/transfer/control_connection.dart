import 'dart:async';
import 'dart:io';

import 'package:sharely_core/src/pairing/device_endpoint.dart';
import 'package:sharely_core/src/protocol/message_codec.dart';
import 'package:sharely_core/src/protocol/protocol_exception.dart';
import 'package:sharely_core/src/protocol/protocol_message.dart';
import 'package:sharely_core/src/transfer/transfer_exception.dart';
import 'package:sharely_core/src/transfer/transfer_paths.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/status.dart' as close_status;
import 'package:web_socket_channel/web_socket_channel.dart';

/// Detects a peer that vanished without closing (Wi-Fi off, laptop asleep).
const controlPingInterval = Duration(seconds: 15);

/// More messages than this in one [controlFloodWindow] is not a person
/// using the app; real use is a handful of offers, answers and notes.
const maxControlMessagesPerWindow = 120;
const controlFloodWindow = Duration(seconds: 10);

/// Sent when a peer breaks the protocol. Apps may only use 1000 or 3000-4999,
/// so this mirrors the standard 1008 "policy violation" in the app range.
const protocolViolationCloseCode = 4008;

/// One end of the control WebSocket: validated messages in, messages out.
///
/// A frame that fails validation closes the connection; it is never trusted.
class ControlConnection {
  new(this._channel) {
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
  final _sinceWindowStart = Stopwatch()..start();
  int _messagesInWindow = 0;

  /// Opens an authenticated control channel to a laptop's server.
  ///
  /// Throws [TransferException] with [TransferFailure.unreachable] on failure.
  static Future<ControlConnection> connect(
    DeviceEndpoint endpoint, {
    required Map<String, String> authHeaders,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final client = endpoint.createHttpClient(connectionTimeout: timeout);
    final channel = IOWebSocketChannel.connect(
      endpoint.webSocketUri(controlChannelPath),
      headers: authHeaders,
      pingInterval: controlPingInterval,
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
    return ControlConnection(channel);
  }

  Stream<ProtocolMessage> get messages => _messages.stream;

  Future<void> get done => _closed.future;

  bool get isOpen => !_closed.isCompleted;

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
    try {
      _messages.add(MessageCodec.decode(frame));
    } on ProtocolException {
      _rejectPeer();
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
    _closed.complete();
    unawaited(_messages.close());
  }
}
