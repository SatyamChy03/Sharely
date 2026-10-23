import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:sharely_core/sharely_core.dart';
import 'package:sharely_core/src/transfer/upload_checksum.dart';
import 'package:sharely_core/src/transfer/xxh64_accumulator.dart';
import 'package:test/test.dart';

import '../support/test_tls.dart';
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

    test(
      'a phone that goes silent is shown as gone within the limit',
      () async {
        // A peer that completes the handshake and then never answers again,
        // as a frozen app or a phone that left the Wi-Fi does.
        final silent = await SecureSocket.connect(
          harness.server.address,
          harness.server.port,
          onBadCertificate: (_) => true,
        );
        addTearDown(silent.destroy);
        final headers = harness.authHeadersFor(phone);
        silent.write(
          'GET /v1/control HTTP/1.1\r\n'
          'Host: laptop\r\n'
          'Upgrade: websocket\r\n'
          'Connection: Upgrade\r\n'
          'Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\n'
          'Sec-WebSocket-Version: 13\r\n'
          '${headers.entries.map((h) => '${h.key}: ${h.value}\r\n').join()}'
          '\r\n',
        );
        final hub = harness.receiver.hub;
        await hub.connects.first.timeout(const Duration(seconds: 5));
        expect(hub.connectedDeviceIds, {phone.deviceId});
        final sinceConnected = Stopwatch()..start();

        await hub.disconnects.first.timeout(
          controlSilenceLimit +
              controlPingInterval +
              const Duration(seconds: 2),
        );

        expect(
          sinceConnected.elapsed,
          lessThan(
            controlSilenceLimit +
                controlPingInterval +
                const Duration(seconds: 1),
          ),
        );
        expect(hub.connectedDeviceIds, isEmpty);
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );

    test('a live link answers when asked, and the app never sees it', () async {
      final connection = await harness.connect();
      final seenByLaptop = harness.receiver.hub.messages.toList();
      final seenByPhone = connection.messages.toList();

      expect(await connection.isAlive(), isTrue);

      await connection.close();
      await harness.receiver.close();
      expect(await seenByLaptop, isEmpty);
      expect(await seenByPhone, isEmpty);
    });

    test('a link whose other end stopped answering is reported dead', () async {
      final mute = await HttpServer.bindSecure(
        InternetAddress.loopbackIPv4,
        0,
        testIdentity.createServerContext(),
      );
      addTearDown(() => mute.close(force: true));
      mute.listen((request) async {
        final socket = await WebSocketTransformer.upgrade(request);
        // Answers with something, but never with the id it was asked.
        socket.listen(
          (_) => socket.add('{"type":"pong","id":"stale_0123456789abcd"}'),
        );
      });
      final connection = await ControlConnection.connect(
        DeviceEndpoint(
          host: mute.address,
          port: mute.port,
          certFingerprint: testIdentity.fingerprint,
        ),
        authHeaders: harness.authHeadersFor(phone),
      );
      addTearDown(connection.close);

      final isAlive = await connection.isAlive(
        timeout: const Duration(milliseconds: 300),
      );

      expect(isAlive, isFalse);
      expect(connection.isOpen, isTrue);
    });

    test('a closed link is not alive', () async {
      final connection = await harness.connect();
      await connection.close();

      expect(await connection.isAlive(), isFalse);
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
