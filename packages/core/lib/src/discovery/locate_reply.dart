import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:meta/meta.dart';
import 'package:sharely_core/src/discovery/discovery_datagram.dart';
import 'package:sharely_core/src/pairing/lan_address.dart';
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
    required this.host,
    required this.port,
    required this.proof,
  });

  factory signed({
    required String nonce,
    required String deviceId,
    required InternetAddress host,
    required int port,
    required String authToken,
  }) {
    return LocateReply(
      deviceId: deviceId,
      host: host,
      port: port,
      proof: _computeProof(nonce, deviceId, host, port, authToken),
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
      host: parsePrivateLanHost(fields.string('host', maxLength: 15)),
      port: parseServicePort(fields.integer('port', min: 0, max: 65535)),
      proof: fields.string(
        'proof',
        minLength: _proofChars,
        maxLength: _proofChars,
      ),
    );
  }

  final String deviceId;

  /// Covered by the proof, so a relayed reply cannot redirect the phone.
  final InternetAddress host;
  final int port;

  final String proof;

  bool isProofValid({required String nonce, required String authToken}) {
    return constantTimeEquals(
      proof,
      _computeProof(nonce, deviceId, host, port, authToken),
    );
  }

  List<int> encode() => encodeDiscoveryDatagram(_type, {
    'deviceId': deviceId,
    'host': host.address,
    'port': port,
    'proof': proof,
  });
}

String _computeProof(
  String nonce,
  String deviceId,
  InternetAddress host,
  int port,
  String authToken,
) {
  final signedText =
      'sharely-locate-v1\n$nonce\n$deviceId\n'
      '${host.address}\n$port';
  return Hmac(
    sha256,
    utf8.encode(authToken),
  ).convert(utf8.encode(signedText)).toString();
}
