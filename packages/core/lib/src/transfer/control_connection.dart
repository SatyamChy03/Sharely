import 'dart:async';

import 'package:sharely_core/src/pairing/device_endpoint.dart';
import 'package:sharely_core/src/protocol/message_codec.dart';
import 'package:sharely_core/src/protocol/protocol_exception.dart';
import 'package:sharely_core/src/protocol/protocol_message.dart';
import 'package:sharely_core/src/transfer/transfer_paths.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/status.dart' as close_status;
import 'package:web_socket_channel/web_socket_channel.dart';

/// Detects a peer that vanished without closing (Wi-Fi off, laptop asleep).
const controlPingInterval = Duration(seconds: 15);

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

  /// Opens an authenticated control channel to a laptop's server.
  static Future<ControlConnection> connect(
    DeviceEndpoint endpoint, {
    required Map<String, String> authHeaders,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final channel = IOWebSocketChannel.connect(
      endpoint.webSocketUri(controlChannelPath),
      headers: authHeaders,
      pingInterval: controlPingInterval,
      connectTimeout: timeout,
    );
    await channel.ready;
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
    if (frame is! String) return _rejectPeer();
    try {
      _messages.add(MessageCodec.decode(frame));
    } on ProtocolException {
      _rejectPeer();
    }
  }

  void _rejectPeer() => unawaited(close(protocolViolationCloseCode));

  void _markClosed() {
    if (_closed.isCompleted) return;
    _closed.complete();
    unawaited(_messages.close());
  }
}
