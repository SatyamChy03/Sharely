import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:sharely_core/sharely_core.dart';
import 'package:test/test.dart';

import 'transfer_harness.dart';

const _transferId = 'transfer_0123456789';

OfferMessage _offerFor(List<int> bytes, {String name = 'a.txt', String? hash}) {
  return OfferMessage(
    transferId: _transferId,
    files: [
      OfferedFile(
        name: name,
        sizeBytes: bytes.length,
        mimeType: 'text/plain',
        sha256: hash ?? sha256.convert(bytes).toString(),
      ),
    ],
  );
}

Future<int> _put(
  TransferHarness harness,
  List<int> bytes, {
  Map<String, String>? headers,
  String path = '/v1/transfers/$_transferId/0',
  int? contentLength,
}) async {
  final client = HttpClient();
  try {
    final request = await client.putUrl(harness.endpoint.httpUri(path));
    (headers ?? harness.authHeadersFor(phone)).forEach(request.headers.set);
    if (contentLength != null) request.contentLength = contentLength;
    request.add(bytes);
    final response = await request.close();
    await response.drain<void>();
    return response.statusCode;
  } finally {
    client.close(force: true);
  }
}

/// Offers [offer] over a fresh control connection and waits until it lands.
Future<void> _offer(
  TransferHarness harness,
  OfferMessage offer, {
  bool accept = true,
}) async {
  final received = harness.receiver.events
      .whereType<IncomingOfferReceived>()
      .first;
  (await harness.connect()).send(offer);
  await received;
  if (accept) harness.receiver.accept(offer.transferId);
}

void main() {
  late TransferHarness harness;

  setUp(() async => harness = await TransferHarness.start());

  group('authentication', () {
    final forgedHeaders = {
      'a wrong token': buildAuthHeaders(
        localDeviceId: phone.deviceId,
        authToken: 'auth_wrongwrongwrongwrong',
      ),
      'an unpaired device': buildAuthHeaders(
        localDeviceId: 'stranger_0123456789',
        authToken: phone.authToken,
      ),
      'no credentials': <String, String>{},
    };
    for (final MapEntry(key: description, value: headers)
        in forgedHeaders.entries) {
      test('the control channel refuses $description', () async {
        await expectLater(
          ControlConnection.connect(harness.endpoint, authHeaders: headers),
          throwsA(anything),
        );
      });

      test('uploads refuse $description', () async {
        expect(await _put(harness, [1], headers: headers), 401);
      });
    }

    test("one paired device can't upload into another's transfer", () async {
      await _offer(harness, _offerFor('mine'.codeUnits));

      final status = await _put(
        harness,
        'mine'.codeUnits,
        headers: harness.authHeadersFor(otherPhone),
      );

      expect(status, 404);
    });
  });

  group('uploads', () {
    test('are refused before the laptop accepts', () async {
      await _offer(harness, _offerFor('x'.codeUnits), accept: false);

      expect(await _put(harness, 'x'.codeUnits), 409);
    });

    test('with altered bytes are discarded as corrupted', () async {
      final ended = harness.receiver.events
          .whereType<IncomingTransferEnded>()
          .first;
      await _offer(harness, _offerFor('original'.codeUnits));

      expect(await _put(harness, 'tampered'.codeUnits), 422);
      expect((await ended).reason, TransferFailure.corrupted);
      expect(harness.savedFiles(), isEmpty);
    });

    test('that grow past their declared size are discarded', () async {
      await _offer(harness, _offerFor('tiny'.codeUnits));

      expect(await _put(harness, List.filled(64 * 1024, 7)), 422);
      expect(harness.savedFiles(), isEmpty);
    });

    test(
      'with a Content-Length that contradicts the offer are refused',
      () async {
        await _offer(harness, _offerFor('tiny'.codeUnits));

        final status = await _put(
          harness,
          List.filled(64 * 1024, 7),
          contentLength: 64 * 1024,
        );

        expect(status, 400);
        expect(harness.savedFiles(), isEmpty);
      },
    );

    test('of the same file twice are refused', () async {
      final bytes = List.filled(256 * 1024, 1);
      await _offer(harness, _offerFor(bytes));
      final first = _put(harness, bytes);

      expect(await _put(harness, bytes), 409);
      await first;
    });

    test('to an unknown file index are refused', () async {
      await _offer(harness, _offerFor('x'.codeUnits));

      final status = await _put(
        harness,
        'x'.codeUnits,
        path: '/v1/transfers/$_transferId/7',
      );

      expect(status, 404);
    });

    test('with a path-traversal name stay inside the save folder', () async {
      final bytes = utf8.encode('escape attempt');
      await _offer(harness, _offerFor(bytes, name: '../../outside.txt'));

      expect(await _put(harness, bytes), 204);
      final saved = harness.savedFiles().single;
      expect(saved.parent.path, harness.saveDirectory.path);
    });
  });

  group('control channel', () {
    test('a malformed frame closes the connection', () async {
      final connection = await harness.connect();
      final offerWithoutChecksum = jsonEncode({
        'type': 'offer',
        'transferId': _transferId,
        'files': [
          {'name': 'a.txt', 'size': 1, 'mime': 'text/plain'},
        ],
      });
      final socket =
          await WebSocket.connect(
              harness.endpoint.webSocketUri('/v1/control').toString(),
              headers: harness.authHeadersFor(otherPhone),
            )
            ..add(offerWithoutChecksum);

      await socket.drain<void>().timeout(const Duration(seconds: 5));

      expect(socket.closeCode, protocolViolationCloseCode);
      expect(connection.isOpen, isTrue);
    });

    test('a device gets at most three offers awaiting an answer', () async {
      final connection = await harness.connect();
      final decisions = connection.messages
          .whereType<TransferDecisionMessage>()
          .first;
      for (var i = 0; i < 4; i++) {
        connection.send(
          OfferMessage(
            transferId: 'transfer_${'$i'.padLeft(10, '0')}',
            files: _offerFor('x'.codeUnits).files,
          ),
        );
      }

      final decision = await decisions;
      expect(decision.type, MessageType.reject);
      expect(decision.transferId, 'transfer_0000000003');
    });
  });
}
