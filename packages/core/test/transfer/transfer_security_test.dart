import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:sharely_core/sharely_core.dart';
import 'package:sharely_core/src/transfer/upload_checksum.dart';
import 'package:sharely_core/src/transfer/xxh64_accumulator.dart';
import 'package:test/test.dart';

import 'transfer_harness.dart';

const _transferId = 'transfer_0123456789';

OfferMessage _offerFor(List<int> bytes, {String name = 'a.txt'}) {
  return OfferMessage(
    transferId: _transferId,
    files: [
      OfferedFile(name: name, sizeBytes: bytes.length, mimeType: 'text/plain'),
    ],
  );
}

/// An upload body: [bytes], then the checksum of [checksumOf] (or [bytes]).
List<int> _bodyFor(List<int> bytes, {List<int>? checksumOf}) {
  final hasher = Xxh64Accumulator()..add(checksumOf ?? bytes);
  return [...bytes, ...encodeUploadChecksum(hasher.finish())];
}

Future<int> _put(
  TransferHarness harness,
  List<int> bytes, {
  Map<String, String>? headers,
  String path = '/v1/transfers/$_transferId/0',
  int? contentLength,
}) async {
  final client = harness.endpoint.createHttpClient();
  try {
    final request = await client.putUrl(harness.endpoint.httpsUri(path));
    (headers ?? harness.authHeadersFor(phone)).forEach(request.headers.set);
    if (contentLength != null) request.contentLength = contentLength;
    request.add(bytes);
    final response = await request.close();
    await response.drain<void>();
    return response.statusCode;
  } on IOException {
    return _droppedConnection;
  } finally {
    client.close(force: true);
  }
}

/// The laptop may hang up on a refused upload before the rest of the body
/// is sent, so the sender sees a dropped connection, not the status.
const _droppedConnection = -1;

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
          throwsA(isA<TransferException>()),
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
        _bodyFor('mine'.codeUnits),
        headers: harness.authHeadersFor(otherPhone),
      );

      expect(status, 404);
    });
  });

  group('uploads', () {
    test('are refused before the laptop accepts', () async {
      await _offer(harness, _offerFor('x'.codeUnits), accept: false);

      expect(await _put(harness, _bodyFor('x'.codeUnits)), 404);
      expect(harness.savedFiles(), isEmpty);
    });

    test('with altered bytes are discarded as corrupted', () async {
      final ended = harness.receiver.events
          .whereType<IncomingTransferEnded>()
          .first;
      await _offer(harness, _offerFor('original'.codeUnits));

      final tampered = _bodyFor(
        'tampered'.codeUnits,
        checksumOf: 'original'.codeUnits,
      );

      expect(await _put(harness, tampered), 422);
      expect((await ended).reason, TransferFailure.corrupted);
      expect(harness.savedFiles(), isEmpty);
    });

    test('with a wrong checksum are discarded as corrupted', () async {
      await _offer(harness, _offerFor('original'.codeUnits));
      final body = _bodyFor('original'.codeUnits)..last ^= 1;

      expect(await _put(harness, body), 422);
      expect(harness.savedFiles(), isEmpty);
    });

    test('without the trailing checksum are discarded', () async {
      await _offer(harness, _offerFor('original'.codeUnits));

      expect(await _put(harness, 'original'.codeUnits), 422);
      expect(harness.savedFiles(), isEmpty);
    });

    test('that grow past their declared size are discarded', () async {
      await _offer(harness, _offerFor('tiny'.codeUnits));

      final ended = harness.receiver.events
          .whereType<IncomingTransferEnded>()
          .first;

      final status = await _put(harness, List.filled(64 * 1024, 7));

      expect(status, anyOf(422, _droppedConnection));
      expect((await ended).reason, TransferFailure.corrupted);
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
      final first = _put(harness, _bodyFor(bytes));

      final second = await _put(harness, _bodyFor(bytes));

      expect(second, anyOf(409, _droppedConnection));
      await first;
    });

    test('to an unknown file index are refused', () async {
      await _offer(harness, _offerFor('x'.codeUnits));

      final status = await _put(
        harness,
        _bodyFor('x'.codeUnits),
        path: '/v1/transfers/$_transferId/7',
      );

      expect(status, 404);
    });

    test('with a path-traversal name stay inside the save folder', () async {
      final bytes = utf8.encode('escape attempt');
      await _offer(harness, _offerFor(bytes, name: '../../outside.txt'));

      expect(await _put(harness, _bodyFor(bytes)), 204);
      final saved = harness.savedFiles().single;
      expect(saved.parent.path, harness.saveDirectory.path);
    });
  });

  group('control channel', () {
    test('a malformed frame closes the connection', () async {
      final connection = await harness.connect();
      // The checksum field older versions put in offers is now unknown.
      final offerWithUnknownField = jsonEncode({
        'type': 'offer',
        'transferId': _transferId,
        'files': [
          {
            'name': 'a.txt',
            'size': 1,
            'mime': 'text/plain',
            'sha256': 'ab' * 32,
          },
        ],
      });
      final socket =
          await WebSocket.connect(
              harness.endpoint.webSocketUri('/v1/control').toString(),
              headers: harness.authHeadersFor(otherPhone),
              customClient: harness.endpoint.createHttpClient(),
            )
            ..add(offerWithUnknownField);

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

    test(
      'accepting everything still caps how many transfers stay open',
      () async {
        harness.acceptEveryOffer();
        final connection = await harness.connect();
        final rejections = connection.messages
            .whereType<TransferDecisionMessage>()
            .where((decision) => decision.type == MessageType.reject)
            .first;
        for (var i = 0; i < 9; i++) {
          connection.send(
            OfferMessage(
              transferId: 'transfer_${'$i'.padLeft(10, '0')}',
              files: _offerFor('x'.codeUnits).files,
            ),
          );
          // Each offer is accepted before the next one arrives.
          await pumpEventQueue();
        }

        expect((await rejections).transferId, 'transfer_0000000008');
      },
    );

    test('an offer nobody answers is withdrawn', () async {
      final harness = await TransferHarness.start(
        offerLifetime: const Duration(milliseconds: 150),
      );
      final ended = harness.receiver.events
          .whereType<IncomingTransferEnded>()
          .first;
      final connection = await harness.connect();
      final withdrawal = connection.messages
          .whereType<TransferDecisionMessage>()
          .first;

      connection.send(_offerFor('x'.codeUnits));

      expect((await ended).reason, TransferFailure.timedOut);
      expect((await withdrawal).type, MessageType.cancel);
    });

    test('an answered offer is not withdrawn later', () async {
      final harness = await TransferHarness.start(
        offerLifetime: const Duration(milliseconds: 150),
      );
      await _offer(harness, _offerFor('mine'.codeUnits));

      await Future<void>.delayed(const Duration(milliseconds: 400));

      expect(await _put(harness, _bodyFor('mine'.codeUnits)), 204);
    });

    test('a revoked device loses the connection it already had', () async {
      final connection = await harness.connect();
      final other = await harness.connect(otherPhone);
      final notes = harness.receiver.hub.messages.toList();

      harness.receiver.hub.disconnect(phone.deviceId);
      await connection.done.timeout(const Duration(seconds: 5));
      connection.send(const TextContentMessage.text('still here?'));
      await pumpEventQueue();

      expect(harness.receiver.hub.isConnected(phone.deviceId), isFalse);
      expect(other.isOpen, isTrue);
      await harness.receiver.close();
      expect(await notes, isEmpty);
    });

    test('a device that floods the channel is disconnected', () async {
      final connection = await harness.connect();
      final notes = harness.receiver.hub.messages.toList();

      for (var i = 0; i <= maxControlMessagesPerWindow; i++) {
        connection.send(const TextContentMessage.text('again'));
      }
      await connection.done.timeout(const Duration(seconds: 5));
      await harness.receiver.close();

      expect(await notes, hasLength(maxControlMessagesPerWindow));
    });
  });
}
