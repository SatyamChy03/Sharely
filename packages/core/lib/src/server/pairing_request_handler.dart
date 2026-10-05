import 'dart:convert';

import 'package:sharely_core/src/net/bounded_body.dart';
import 'package:sharely_core/src/pairing/paired_device.dart';
import 'package:sharely_core/src/pairing/pairing_session.dart';
import 'package:sharely_core/src/protocol/json_fields.dart';
import 'package:sharely_core/src/protocol/protocol_exception.dart';
import 'package:sharely_core/src/protocol/protocol_message.dart';
import 'package:sharely_core/src/security/secure_id.dart';
import 'package:shelf/shelf.dart';

const int _maxRequestBytes = 4 * 1024;
const _jsonHeaders = {'content-type': 'application/json'};

typedef PairingRequest = ({String secret, HelloMessage hello});

/// Laptop side of `POST /v1/pair`: trades a one-time secret for a long-term
/// auth token. Every failure returns the same bare status, revealing nothing.
class PairingRequestHandler {
  new({
    required this.currentSession,
    required this.localHello,
    required this.onPaired,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final PairingSession? Function() currentSession;
  final HelloMessage localHello;
  final void Function(PairedDevice device) onPaired;
  final DateTime Function() _clock;

  /// `GET /v1/hello`: lets a phone typing a code find this laptop. It reveals
  /// only what the QR code shows anyway: the laptop's id, name and platform.
  Response handleHello(Request request) =>
      Response.ok(jsonEncode(localHello.toJson()), headers: _jsonHeaders);

  Future<Response> handle(Request request) async {
    final PairingRequest pairingRequest;
    try {
      final body = await readBoundedUtf8(request.read(), _maxRequestBytes);
      pairingRequest = parsePairingRequest(body);
    } on ProtocolException {
      return Response.badRequest();
    }
    final session = currentSession();
    if (session == null || !session.redeem(pairingRequest.secret)) {
      return Response.forbidden(null);
    }
    final authToken = generateSecureId(byteLength: 32);
    onPaired(
      PairedDevice.fromHello(
        pairingRequest.hello,
        authToken: authToken,
        pairedAt: _clock(),
      ),
    );
    final reply = {'authToken': authToken, 'hello': localHello.toJson()};
    return Response.ok(jsonEncode(reply), headers: _jsonHeaders);
  }
}

/// Body shape: `{"secret": "<token or code>", "hello": {<hello message>}}`.
PairingRequest parsePairingRequest(String body) {
  final fields = JsonFields(decodeJsonObject(body))
    ..requireOnlyKeys(const {'secret', 'hello'});
  return (
    secret: fields.string('secret', minLength: 6, maxLength: 64),
    hello: parseNestedHello(fields.object('hello')),
  );
}

HelloMessage parseNestedHello(JsonFields helloFields) {
  if (helloFields.string('type', maxLength: 16) != MessageType.hello.name) {
    throw const ProtocolException('Expected a hello message');
  }
  return HelloMessage.fromFields(helloFields);
}
