import 'dart:async';
import 'dart:io';

import 'package:sharely_core/src/discovery/discovery_datagram.dart';
import 'package:sharely_core/src/discovery/locate_query.dart';
import 'package:sharely_core/src/discovery/locate_reply.dart';
import 'package:sharely_core/src/pairing/device_endpoint.dart';
import 'package:sharely_core/src/pairing/lan_address.dart';
import 'package:sharely_core/src/protocol/protocol_exception.dart';
import 'package:sharely_core/src/server/request_authenticator.dart';
import 'package:sharely_core/src/server/sharely_server.dart';

/// Answers paired phones that ask where the laptop's server is.
///
/// Unpaired or malformed queries get no reply at all.
class DiscoveryResponder {
  new _(this._socket);

  final RawDatagramSocket _socket;

  int get port => _socket.port;

  /// Throws a [SocketException] when the discovery port is unavailable.
  static Future<DiscoveryResponder> start({
    required String localDeviceId,
    required DeviceEndpoint serverEndpoint,
    required PairedDeviceLookup findPairedDevice,
    InternetAddress? bindAddress,
    int port = defaultSharelyPort,
  }) async {
    // Broadcasts only reach a socket bound to the wildcard address.
    final socket = await RawDatagramSocket.bind(
      bindAddress ?? InternetAddress.anyIPv4,
      port,
    );
    if (bindAddress == null) await _joinDiscoveryGroup(socket);
    final responder = DiscoveryResponder._(socket);
    socket.listen((event) {
      if (event != RawSocketEvent.read) return;
      final datagram = socket.receive();
      if (datagram == null) return;
      final reply = _answer(
        datagram,
        localDeviceId,
        serverEndpoint,
        findPairedDevice,
      );
      if (reply != null) responder._send(reply, datagram);
    });
    return responder;
  }

  void stop() => _socket.close();

  void _send(LocateReply reply, Datagram query) {
    try {
      _socket.send(reply.encode(), query.address, query.port);
    } on SocketException {
      // The phone asks again on its next attempt.
      return;
    }
  }
}

/// Listens for the group on every network the laptop is on. Who may be
/// answered is unchanged: [_answer] still replies to paired devices only.
Future<void> _joinDiscoveryGroup(RawDatagramSocket socket) async {
  final interfaces = await NetworkInterface.list(
    type: InternetAddressType.IPv4,
    includeLoopback: true,
  );
  for (final interface in interfaces) {
    try {
      socket.joinMulticast(discoveryMulticastGroup, interface);
    } on OSError {
      // An adapter without multicast; broadcast and direct asks still work.
      continue;
    } on SocketException {
      continue;
    }
  }
}

LocateReply? _answer(
  Datagram datagram,
  String localDeviceId,
  DeviceEndpoint serverEndpoint,
  PairedDeviceLookup findPairedDevice,
) {
  final sender = datagram.address;
  if (!isPrivateLanAddress(sender) && !sender.isLoopback) return null;
  final LocateQuery query;
  try {
    query = LocateQuery.decode(datagram.data);
  } on ProtocolException {
    return null;
  }
  final phone = findPairedDevice(query.fromDeviceId);
  if (phone == null) return null;
  return LocateReply.signed(
    nonce: query.nonce,
    deviceId: localDeviceId,
    host: serverEndpoint.host,
    port: serverEndpoint.port,
    authToken: phone.authToken,
  );
}
