import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:sharely_core/src/net/bounded_body.dart';
import 'package:sharely_core/src/pairing/paired_device.dart';
import 'package:sharely_core/src/pairing/pairing_exception.dart';
import 'package:sharely_core/src/pairing/pairing_invite.dart';
import 'package:sharely_core/src/protocol/json_fields.dart';
import 'package:sharely_core/src/protocol/protocol_exception.dart';
import 'package:sharely_core/src/protocol/protocol_message.dart';
import 'package:sharely_core/src/server/pairing_request_handler.dart';

const int _maxResponseBytes = 16 * 1024;

/// Phone side of pairing: redeems the invite and returns the trusted laptop.
class PairingClient {
  const new({this.timeout = const Duration(seconds: 8)});

  final Duration timeout;

  Future<PairedDevice> pair({
    required PairingInvite invite,
    required HelloMessage localHello,
  }) async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final body = await _postPairingRequest(client, invite, localHello);
      return _parseReply(body, invite);
    } on SocketException {
      throw const PairingException(PairingFailure.unreachable);
    } on TimeoutException {
      throw const PairingException(PairingFailure.unreachable);
    } on HttpException {
      throw const PairingException(PairingFailure.unreachable);
    } on ProtocolException {
      throw const PairingException(PairingFailure.invalidResponse);
    } finally {
      client.close(force: true);
    }
  }

  Future<String> _postPairingRequest(
    HttpClient client,
    PairingInvite invite,
    HelloMessage localHello,
  ) async {
    final request = await client.post(
      invite.host.address,
      invite.port,
      '/v1/pair',
    );
    request.headers.contentType = ContentType.json;
    request.write(
      jsonEncode({'secret': invite.token, 'hello': localHello.toJson()}),
    );
    final response = await request.close().timeout(timeout);
    if (response.statusCode == HttpStatus.forbidden) {
      throw const PairingException(PairingFailure.rejected);
    }
    if (response.statusCode != HttpStatus.ok) {
      throw const PairingException(PairingFailure.invalidResponse);
    }
    return await readBoundedUtf8(response, _maxResponseBytes).timeout(timeout);
  }

  PairedDevice _parseReply(String body, PairingInvite invite) {
    final fields = JsonFields(decodeJsonObject(body))
      ..requireOnlyKeys(const {'authToken', 'hello'});
    final authToken = fields.id('authToken');
    final laptopHello = parseNestedHello(fields.object('hello'));
    // A different machine answering at that address is not the one we scanned.
    if (laptopHello.deviceId != invite.deviceId) {
      throw const PairingException(PairingFailure.invalidResponse);
    }
    return PairedDevice.fromHello(
      laptopHello,
      authToken: authToken,
      pairedAt: DateTime.now(),
    );
  }
}
