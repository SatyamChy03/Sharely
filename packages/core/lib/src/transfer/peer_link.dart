import 'package:sharely_core/src/pairing/device_endpoint.dart';
import 'package:sharely_core/src/transfer/control_connection.dart';

/// The phone's live link to its laptop; a new one after every reconnect.
typedef PeerLink = ({ControlConnection connection, DeviceEndpoint endpoint});

/// Waits for the link to come back. Returns null when it did not within
/// [timeout], which ends the transfer.
typedef PeerReconnect = Future<PeerLink?> Function(Duration timeout);

/// The link after a reconnect; null when there is no [reconnect], no
/// [timeLeft], or the transfer is [abandoned] while waiting.
Future<PeerLink?> awaitNewLink(
  PeerReconnect? reconnect, {
  required Duration timeLeft,
  required Future<void> abandoned,
}) async {
  if (reconnect == null || timeLeft <= Duration.zero) return null;
  return await Future.any([
    reconnect(timeLeft),
    abandoned.then<PeerLink?>((_) => null),
  ]);
}
