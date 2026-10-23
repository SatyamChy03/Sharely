import 'dart:async';
import 'dart:io';

import 'package:sharely_core/src/discovery/discovery_datagram.dart';
import 'package:sharely_core/src/discovery/locate_query.dart';
import 'package:sharely_core/src/discovery/locate_reply.dart';
import 'package:sharely_core/src/pairing/device_endpoint.dart';
import 'package:sharely_core/src/pairing/lan_address.dart';
import 'package:sharely_core/src/pairing/laptop_finder.dart';
import 'package:sharely_core/src/pairing/paired_device.dart';
import 'package:sharely_core/src/protocol/protocol_exception.dart';
import 'package:sharely_core/src/security/secure_id.dart';
import 'package:sharely_core/src/server/sharely_server.dart';

// More adapters than this is a VM or VPN host; the real Wi-Fi ranks first.
const int _maxInterfacesAsked = 4;

/// Finds a paired laptop again after its address on the Wi-Fi has changed.
///
/// The question goes out on every network this phone is on, so it also
/// reaches a laptop joined to the phone's own hotspot.
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
  /// By default each of this phone's [localAddresses] asks the multicast
  /// group, the broadcast address and its own /24, since networks differ
  /// in which of those they let through. [targets] replaces that list.
  Future<DeviceEndpoint?> locate({
    required PairedDevice laptop,
    required String localDeviceId,
    Iterable<InternetAddress>? targets,
    Iterable<InternetAddress>? localAddresses,
  }) async {
    final nonce = generateSecureId();
    final query = LocateQuery(
      fromDeviceId: localDeviceId,
      nonce: nonce,
    ).encode();
    final found = Completer<DeviceEndpoint>();
    final routes = await _openRoutes(
      targets: targets,
      localAddresses: localAddresses,
      onDatagram: (datagram) {
        final endpoint = _readReply(datagram, laptop, nonce);
        if (endpoint != null && !found.isCompleted) found.complete(endpoint);
      },
    );
    try {
      for (var round = 0; round < rounds && routes.isNotEmpty; round++) {
        for (final route in routes) {
          _sendToAll(route.socket, query, route.destinations);
        }
        final endpoint = await _waitFor(found.future);
        if (endpoint != null) return endpoint;
      }
      return null;
    } finally {
      for (final route in routes) {
        route.socket.close();
      }
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

typedef _Route = ({
  RawDatagramSocket socket,
  List<InternetAddress> destinations,
});

/// One socket per local address: a socket bound to an address sends its
/// multicast and broadcast out of that network, not just the default one.
Future<List<_Route>> _openRoutes({
  required Iterable<InternetAddress>? targets,
  required Iterable<InternetAddress>? localAddresses,
  required void Function(Datagram? datagram) onDatagram,
}) async {
  final sources = localAddresses == null && targets != null
      ? [InternetAddress.anyIPv4]
      : [...localAddresses ?? await findLanAddresses()];
  final routes = <_Route>[];
  for (final source in sources.take(_maxInterfacesAsked)) {
    final RawDatagramSocket socket;
    try {
      socket = await RawDatagramSocket.bind(source, 0);
    } on SocketException {
      // That network just went away; the others are still asked.
      continue;
    }
    socket
      ..broadcastEnabled = true
      ..listen((event) {
        if (event == RawSocketEvent.read) onDatagram(socket.receive());
      });
    routes.add((
      socket: socket,
      destinations: [...targets ?? discoveryDestinationsFrom(source)],
    ));
  }
  return routes;
}

/// Everywhere a phone at [ownAddress] asks: the multicast group, the
/// broadcast address, then each neighbour for networks that block both.
List<InternetAddress> discoveryDestinationsFrom(InternetAddress ownAddress) => [
  discoveryMulticastGroup,
  InternetAddress('255.255.255.255'),
  ...neighboursOf(ownAddress),
];

DeviceEndpoint? _readReply(
  Datagram? datagram,
  PairedDevice laptop,
  String nonce,
) {
  final known = laptop.endpoint;
  if (datagram == null || known == null) return null;
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
  // Only the address moved; the certificate to expect is unchanged.
  return known.movedTo(reply.host, reply.port);
}
