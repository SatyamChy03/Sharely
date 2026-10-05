import 'dart:async';

import 'package:sharely_core/src/pairing/paired_device.dart';
import 'package:sharely_core/src/protocol/protocol_message.dart';
import 'package:sharely_core/src/server/request_authenticator.dart';
import 'package:sharely_core/src/transfer/control_connection.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';

typedef DeviceMessage = ({PairedDevice sender, ProtocolMessage message});

/// Laptop side: one live control connection per paired device.
class ControlHub {
  final _connections = <String, ControlConnection>{};
  final _messages = StreamController<DeviceMessage>.broadcast();
  final _disconnects = StreamController<String>.broadcast();
  final _connects = StreamController<String>.broadcast();

  /// Validated messages, tagged with the paired device that sent them.
  Stream<DeviceMessage> get messages => _messages.stream;

  /// Device ids that just opened a control connection.
  Stream<String> get connects => _connects.stream;

  /// Device ids whose control connection just closed.
  Stream<String> get disconnects => _disconnects.stream;

  bool isConnected(String deviceId) => _connections.containsKey(deviceId);

  /// Upgrades a request already admitted by [requirePairedDevice].
  FutureOr<Response> handleUpgrade(Request request) {
    final device = authenticatedDevice(request);
    final upgrade = webSocketHandler(
      (channel, _) => _adopt(device, ControlConnection(channel)),
      pingInterval: controlPingInterval,
    );
    return upgrade(request);
  }

  /// Returns false when the device has no open control connection.
  bool send(String deviceId, ProtocolMessage message) {
    final connection = _connections[deviceId];
    if (connection == null) return false;
    connection.send(message);
    return true;
  }

  Future<void> closeAll() async {
    final open = [..._connections.values];
    _connections.clear();
    await Future.wait(open.map((connection) => connection.close()));
    await _messages.close();
    await _disconnects.close();
    await _connects.close();
  }

  void _adopt(PairedDevice device, ControlConnection connection) {
    // A reconnecting phone replaces its stale connection.
    final previous = _connections[device.deviceId];
    _connections[device.deviceId] = connection;
    if (previous != null) unawaited(previous.close());
    if (!_connects.isClosed) _connects.add(device.deviceId);
    connection.messages.listen((message) {
      if (_messages.isClosed) return;
      _messages.add((sender: device, message: message));
    });
    unawaited(
      connection.done.then((_) {
        if (!identical(_connections[device.deviceId], connection)) return;
        _connections.remove(device.deviceId);
        if (!_disconnects.isClosed) _disconnects.add(device.deviceId);
      }),
    );
  }
}
