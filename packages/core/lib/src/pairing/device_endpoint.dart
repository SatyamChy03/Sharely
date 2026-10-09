import 'dart:io';

import 'package:meta/meta.dart';
import 'package:sharely_core/src/pairing/lan_address.dart';
import 'package:sharely_core/src/protocol/protocol_exception.dart';
import 'package:sharely_core/src/security/cert_fingerprint.dart';
import 'package:sharely_core/src/security/pinned_http_client.dart';

/// Where a laptop's server was last reachable on the local network, and
/// the certificate it must present there.
@immutable
final class DeviceEndpoint {
  const new({
    required this.host,
    required this.port,
    required this.certFingerprint,
  });

  /// Validates an untrusted endpoint, as read from storage.
  factory parse({
    required String host,
    required int port,
    required String certFingerprint,
  }) {
    if (!isValidCertFingerprint(certFingerprint)) {
      throw const ProtocolException('Endpoint certificate is invalid');
    }
    return DeviceEndpoint(
      host: parsePrivateLanHost(host),
      port: parseServicePort(port),
      certFingerprint: certFingerprint,
    );
  }

  final InternetAddress host;
  final int port;

  /// Pinned at pairing; it stays the same when the address changes.
  final String certFingerprint;

  /// The same laptop, found again at a new address.
  DeviceEndpoint movedTo(InternetAddress newHost, int newPort) =>
      DeviceEndpoint(
        host: newHost,
        port: newPort,
        certFingerprint: certFingerprint,
      );

  Uri httpsUri(String path) =>
      Uri(scheme: 'https', host: host.address, port: port, path: path);

  Uri webSocketUri(String path) =>
      Uri(scheme: 'wss', host: host.address, port: port, path: path);

  /// A client that refuses every server but this laptop.
  HttpClient createHttpClient({
    Duration connectionTimeout = const Duration(seconds: 8),
  }) => createPinnedHttpClient(
    certFingerprint,
    connectionTimeout: connectionTimeout,
  );

  @override
  bool operator ==(Object other) =>
      other is DeviceEndpoint &&
      other.host == host &&
      other.port == port &&
      other.certFingerprint == certFingerprint;

  @override
  int get hashCode => Object.hash(host, port, certFingerprint);

  @override
  String toString() => '${host.address}:$port';
}
