import 'dart:async';

import 'package:sharely_core/src/pairing/paired_device.dart';
import 'package:sharely_core/src/protocol/protocol_message.dart';
import 'package:sharely_core/src/server/request_authenticator.dart';
import 'package:sharely_core/src/transfer/control_connection.dart';
import 'package:sharely_core/src/transfer/link_liveness.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';

typedef DeviceMessage = ({PairedDevice sender, ProtocolMessage message});

/// Laptop side: one live control connection per paired device.
class ControlHub {
  new({
    this.clock,
    this.checkEvery,
    this.silenceLimit = controlSilenceLimit,
    this.offScreenSilenceLimit = backgroundSilenceLimit,
  });

  /// Passed to every connection; tests use them to stand in for a pause.
  final LivenessClock? clock;
  final Duration? checkEvery;

  /// How long a phone may stay silent while Sharely is on its screen.
  final Duration silenceLimit;

  /// How long a phone may stay silent after saying Sharely is off screen.
  final Duration offScreenSilenceLimit;

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

  /// Every device connected right now, for a listener that starts late.
  Set<String> get connectedDeviceIds => {..._connections.keys};

  /// Upgrades a request already admitted by [requirePairedDevice].
  FutureOr<Response> handleUpgrade(Request request) {
    final device = authenticatedDevice(request);
    // No socket-level pings: [LinkLiveness] in the connection judges
    // silence, and lets a phone that is off screen stay quiet for longer.
    final upgrade = webSocketHandler(
      (channel, _) => _adopt(
        device,
        ControlConnection(
          channel,
          clock: clock,
          checkEvery: checkEvery,
          allowedSilence: silenceLimit,
        ),
      ),
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

  /// Drops [deviceId]'s live connection, as when its pairing is removed:
  /// a revoked device must not keep talking on a socket it opened earlier.
  void disconnect(String deviceId) {
    final connection = _connections.remove(deviceId);
    if (connection == null) return;
    unawaited(connection.close());
    if (!_disconnects.isClosed) _disconnects.add(deviceId);
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
      if (message case PresenceMessage(:final isOnScreen)) {
        connection.allowedSilence = isOnScreen
            ? silenceLimit
            : offScreenSilenceLimit;
        return;
      }
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
