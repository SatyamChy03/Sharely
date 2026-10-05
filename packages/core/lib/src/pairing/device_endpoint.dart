import 'dart:io';

import 'package:meta/meta.dart';
import 'package:sharely_core/src/pairing/lan_address.dart';
import 'package:sharely_core/src/protocol/protocol_exception.dart';

/// Where a laptop's server was last reachable on the local network.
@immutable
final class DeviceEndpoint {
  const new({required this.host, required this.port});

  /// Validates an untrusted host and port, as read from storage.
  factory parse({required String host, required int port}) {
    final address = InternetAddress.tryParse(host);
    if (address == null || !isPrivateLanAddress(address)) {
      throw const ProtocolException('Endpoint host is not a private address');
    }
    if (!isValidServicePort(port)) {
      throw const ProtocolException('Endpoint port is out of range');
    }
    return DeviceEndpoint(host: address, port: port);
  }

  final InternetAddress host;
  final int port;

  Uri httpUri(String path) =>
      Uri(scheme: 'http', host: host.address, port: port, path: path);

  Uri webSocketUri(String path) =>
      Uri(scheme: 'ws', host: host.address, port: port, path: path);

  @override
  bool operator ==(Object other) =>
      other is DeviceEndpoint && other.host == host && other.port == port;

  @override
  int get hashCode => Object.hash(host, port);

  @override
  String toString() => '${host.address}:$port';
}
