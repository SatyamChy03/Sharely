import 'dart:async';
import 'dart:io';

import 'package:sharely_core/src/net/bounded_body.dart';
import 'package:sharely_core/src/pairing/device_endpoint.dart';
import 'package:sharely_core/src/pairing/lan_address.dart';
import 'package:sharely_core/src/protocol/json_fields.dart';
import 'package:sharely_core/src/protocol/protocol_exception.dart';
import 'package:sharely_core/src/protocol/protocol_message.dart';
import 'package:sharely_core/src/server/pairing_request_handler.dart';
import 'package:sharely_core/src/server/sharely_server.dart';

const int _maxHelloBytes = 4 * 1024;

// Enough parallel probes to sweep a /24 in a few seconds without
// exhausting the phone's sockets.
const int _parallelProbes = 48;

typedef FoundLaptop = ({DeviceEndpoint endpoint, HelloMessage hello});

/// Finds Sharely laptops on this Wi-Fi when there is no QR code to scan.
///
/// Until mDNS arrives this sweeps the phone's own /24 on the default port.
class LaptopFinder {
  const new({
    this.port = defaultSharelyPort,
    this.probeTimeout = const Duration(milliseconds: 700),
  });

  final int port;
  final Duration probeTimeout;

  Future<List<FoundLaptop>> findOnLocalNetwork() async {
    final ownAddresses = await findLanAddresses();
    if (ownAddresses.isEmpty) return const [];
    return await probe(neighboursOf(ownAddresses.first));
  }

  /// Asks each candidate for its hello; silent or non-Sharely hosts drop out.
  Future<List<FoundLaptop>> probe(Iterable<InternetAddress> candidates) async {
    final queue = [...candidates];
    final found = <FoundLaptop>[];
    final client = HttpClient()..connectionTimeout = probeTimeout;
    try {
      for (var start = 0; start < queue.length; start += _parallelProbes) {
        final batch = queue.skip(start).take(_parallelProbes);
        final results = await Future.wait(
          batch.map((host) => _askForHello(client, host)),
        );
        found.addAll(results.whereType<FoundLaptop>());
      }
    } finally {
      client.close(force: true);
    }
    return found;
  }

  Future<FoundLaptop?> _askForHello(
    HttpClient client,
    InternetAddress host,
  ) async {
    try {
      final request = await client.get(host.address, port, helloPath);
      final response = await request.close().timeout(probeTimeout * 2);
      if (response.statusCode != HttpStatus.ok) {
        await response.drain<void>();
        return null;
      }
      final body = await readBoundedUtf8(response, _maxHelloBytes);
      final hello = parseNestedHello(JsonFields(decodeJsonObject(body)));
      return (endpoint: DeviceEndpoint(host: host, port: port), hello: hello);
    } on IOException {
      return null;
    } on TimeoutException {
      return null;
    } on ProtocolException {
      return null;
    }
  }
}

/// Every other host in [address]'s /24, the usual home Wi-Fi size.
List<InternetAddress> neighboursOf(InternetAddress address) {
  final [a, b, c, own] = address.rawAddress;
  return [
    for (var host = 1; host < 255; host++)
      if (host != own) InternetAddress('$a.$b.$c.$host'),
  ];
}
