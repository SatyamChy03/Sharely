import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:meta/meta.dart';
import 'package:sharely_core/src/discovery/discovery_datagram.dart';
import 'package:sharely_core/src/pairing/device_endpoint.dart';
import 'package:sharely_core/src/security/constant_time.dart';

const _type = 'located';
const _proofChars = 64;

/// A laptop telling a paired phone where its server is now.
///
/// The proof is keyed with the pairing token, so only the real laptop can
/// answer and the token itself never travels in a datagram.
@immutable
final class LocateReply {
  const new({
    required this.deviceId,
    required this.endpoint,
    required this.proof,
  });

  factory signed({
    required String nonce,
    required String deviceId,
    required DeviceEndpoint endpoint,
    required String authToken,
  }) {
    return LocateReply(
      deviceId: deviceId,
      endpoint: endpoint,
      proof: _computeProof(nonce, deviceId, endpoint, authToken),
    );
  }

  /// Throws a `ProtocolException` unless [datagram] is a valid reply.
  factory decode(List<int> datagram) {
    final fields = decodeDiscoveryDatagram(datagram, expectedType: _type)
      ..requireOnlyKeys(const {
        'type',
        'v',
        'deviceId',
        'host',
        'port',
        'proof',
      });
    return LocateReply(
      deviceId: fields.id('deviceId'),
      endpoint: DeviceEndpoint.parse(
        host: fields.string('host', maxLength: 15),
        port: fields.integer('port', min: 0, max: 65535),
      ),
      proof: fields.string(
        'proof',
        minLength: _proofChars,
        maxLength: _proofChars,
      ),
    );
  }

  final String deviceId;

  /// Covered by the proof, so a relayed reply cannot redirect the phone.
  final DeviceEndpoint endpoint;

  final String proof;

  bool isProofValid({required String nonce, required String authToken}) {
    return constantTimeEquals(
      proof,
      _computeProof(nonce, deviceId, endpoint, authToken),
    );
  }

  List<int> encode() => encodeDiscoveryDatagram(_type, {
    'deviceId': deviceId,
    'host': endpoint.host.address,
    'port': endpoint.port,
    'proof': proof,
  });
}

String _computeProof(
  String nonce,
  String deviceId,
  DeviceEndpoint endpoint,
  String authToken,
) {
  final signedText =
      'sharely-locate-v1\n$nonce\n$deviceId\n'
      '${endpoint.host.address}\n${endpoint.port}';
  return Hmac(
    sha256,
    utf8.encode(authToken),
  ).convert(utf8.encode(signedText)).toString();
}
