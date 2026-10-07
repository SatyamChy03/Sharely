import 'dart:async';
import 'dart:io';

import 'package:sharely_core/src/discovery/locate_query.dart';
import 'package:sharely_core/src/discovery/locate_reply.dart';
import 'package:sharely_core/src/pairing/device_endpoint.dart';
import 'package:sharely_core/src/pairing/lan_address.dart';
import 'package:sharely_core/src/pairing/laptop_finder.dart';
import 'package:sharely_core/src/pairing/paired_device.dart';
import 'package:sharely_core/src/protocol/protocol_exception.dart';
import 'package:sharely_core/src/security/secure_id.dart';
import 'package:sharely_core/src/server/sharely_server.dart';

/// Finds a paired laptop again after its address on the Wi-Fi has changed.
class LaptopLocator {
  const new({
    this.port = defaultSharelyPort,
    this.rounds = 3,
    this.roundTimeout = const Duration(milliseconds: 500),
  });

  final int port;

  /// UDP is lossy, so the question is asked more than once.
  final int rounds;
  final Duration roundTimeout;

  /// The laptop's current endpoint, or null when it does not answer.
  ///
  /// [targets] defaults to the whole Wi-Fi (broadcast) plus this /24, for
  /// routers that drop broadcasts.
  Future<DeviceEndpoint?> locate({
    required PairedDevice laptop,
    required String localDeviceId,
    Iterable<InternetAddress>? targets,
  }) async {
    final destinations = [...targets ?? await _defaultTargets()];
    final nonce = generateSecureId();
    final query = LocateQuery(
      fromDeviceId: localDeviceId,
      nonce: nonce,
    ).encode();
    final RawDatagramSocket socket;
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    } on SocketException {
      return null;
    }
    socket.broadcastEnabled = true;
    final found = Completer<DeviceEndpoint>();
    final replies = socket.listen((event) {
      if (event != RawSocketEvent.read) return;
      final endpoint = _readReply(socket.receive(), laptop, nonce);
      if (endpoint != null && !found.isCompleted) found.complete(endpoint);
    });
    try {
      for (var round = 0; round < rounds; round++) {
        _sendToAll(socket, query, destinations);
        final endpoint = await _waitFor(found.future);
        if (endpoint != null) return endpoint;
      }
      return null;
    } finally {
      await replies.cancel();
      socket.close();
    }
  }

  Future<DeviceEndpoint?> _waitFor(Future<DeviceEndpoint> found) {
    return found
        .then<DeviceEndpoint?>((endpoint) => endpoint)
        .timeout(roundTimeout, onTimeout: () => null);
  }

  void _sendToAll(
    RawDatagramSocket socket,
    List<int> query,
    List<InternetAddress> destinations,
  ) {
    for (final destination in destinations) {
      try {
        socket.send(query, destination, port);
      } on SocketException {
        // Some networks refuse broadcasts; the other targets still go out.
        continue;
      }
    }
  }
}

Future<List<InternetAddress>> _defaultTargets() async {
  final ownAddresses = await findLanAddresses();
  return [
    InternetAddress('255.255.255.255'),
    if (ownAddresses.isNotEmpty) ...neighboursOf(ownAddresses.first),
  ];
}

DeviceEndpoint? _readReply(
  Datagram? datagram,
  PairedDevice laptop,
  String nonce,
) {
  if (datagram == null) return null;
  final LocateReply reply;
  try {
    reply = LocateReply.decode(datagram.data);
  } on ProtocolException {
    return null;
  }
  if (reply.deviceId != laptop.deviceId) return null;
  if (!reply.isProofValid(nonce: nonce, authToken: laptop.authToken)) {
    return null;
  }
  return reply.endpoint;
}
