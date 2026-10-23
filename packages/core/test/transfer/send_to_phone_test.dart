import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:sharely_core/sharely_core.dart';
import 'package:sharely_core/src/transfer/upload_checksum.dart';
import 'package:sharely_core/src/transfer/xxh64_accumulator.dart';
import 'package:test/test.dart';

import '../support/test_tls.dart';

import 'transfer_harness.dart';

List<int> _randomBytes(int length) {
  final random = Random(7);
  return List.generate(length, (_) => random.nextInt(256));
}

/// The phone's half of a laptop-to-phone transfer.
class _Phone {
  new(this.harness, this.connection, this.device)
    : offers = StreamIterator(
        connection.messages.where((m) => m is OfferMessage).cast(),
      );

  final TransferHarness harness;
  final ControlConnection connection;
  final PairedDevice device;
  final StreamIterator<OfferMessage> offers;

  Directory get saveDirectory =>
      Directory('${harness.workDirectory.path}/phone-downloads');

  static Future<_Phone> connect(
    TransferHarness harness, [
    PairedDevice? device,
  ]) async {
    return _Phone(harness, await harness.connect(device), device ?? phone);
  }

  Future<OfferMessage> nextOffer() async {
    expect(await offers.moveNext(), isTrue, reason: 'no offer arrived');
    return offers.current;
  }

  IncomingDownload accept(OfferMessage offer, {DeviceEndpoint? endpoint}) {
    return IncomingDownload.start(
      offer: offer,
      connection: connection,
      endpoint: endpoint ?? harness.endpoint,
      authHeaders: harness.authHeadersFor(device),
      saveDirectory: () async => saveDirectory,
      retryDelay: const Duration(milliseconds: 50),
      resumeWindow: const Duration(seconds: 2),
    );
  }

  List<File> savedFiles() {
    if (!saveDirectory.existsSync()) return const [];
    return saveDirectory.listSync().whereType<File>().toList();
  }
}

/// A file whose bytes arrive only when the test adds them.
({OutgoingFile file, StreamController<List<int>> bytes}) _slowFile(int size) {
  final bytes = StreamController<List<int>>();
  final file = OutgoingFile(
    name: 'slow.bin',
    sizeBytes: size,
    mimeType: 'application/octet-stream',
    openRead: () => bytes.stream,
  );
  // Not awaited: a reader that has stopped listening never lets it finish.
  addTearDown(() => unawaited(bytes.close()));
  return (file: file, bytes: bytes);
}

Future<OutgoingTransferUpdate> _outcomeOf(
  TransferHarness harness,
  String transferId,
) async {
  final event = await harness.sender.events.firstWhere(
    (event) =>
        event.transferId == transferId &&
        (event.update is OutgoingTransferCompleted ||
            event.update is OutgoingTransferFailed),
  );
  return event.update;
}

Matcher _failedWith(TransferFailure reason) =>
    isA<OutgoingTransferFailed>().having((u) => u.reason, 'reason', reason);

Matcher _endedWith(TransferFailure reason) =>
    isA<IncomingTransferEnded>().having((e) => e.reason, 'reason', reason);

Future<int> _get(
  TransferHarness harness,
  String path, {
  Map<String, String>? headers,
}) async {
  final client = harness.endpoint.createHttpClient();
  try {
    final request = await client.getUrl(harness.endpoint.httpsUri(path));
    (headers ?? harness.authHeadersFor(phone)).forEach(request.headers.set);
    final response = await request.close();
    await response.drain<void>();
    return response.statusCode;
  } finally {
    client.close(force: true);
  }
}

/// A stand-in laptop that serves [body] for any download.
Future<DeviceEndpoint> _serveRawBody(List<int> body, {int? declared}) async {
  final server = await HttpServer.bindSecure(
    InternetAddress.loopbackIPv4,
    0,
    testIdentity.createServerContext(),
  );
  addTearDown(() => server.close(force: true));
  server.listen((request) async {
    request.response.contentLength = declared ?? body.length;
    request.response.add(body);
    await request.response.close().catchError((Object _) {});
  });
  return DeviceEndpoint(
    host: server.address,
    port: server.port,
    certFingerprint: testIdentity.fingerprint,
  );
}

OfferMessage _offerOf(List<int> bytes) => OfferMessage(
  transferId: 'transfer_0123456789',
  files: [
    OfferedFile(
      name: 'a.bin',
      sizeBytes: bytes.length,
      mimeType: 'application/octet-stream',
    ),
  ],
);

void main() {
  late TransferHarness harness;

  setUp(() async => harness = await TransferHarness.start());

  test('an accepted offer saves byte-identical files on the phone', () async {
    final apkBytes = _randomBytes(5 * 1024 * 1024 + 3);
    final files = [
      await harness.writeFile('app.apk', apkBytes),
      await harness.writeFile('server.log', 'line one\nline two\n'.codeUnits),
      await harness.writeFile('empty.txt', const []),
    ];
    final receiver = await _Phone.connect(harness);
    final transferId = harness.sender.offerFiles(
      deviceId: phone.deviceId,
      files: files,
    );
    final outcome = _outcomeOf(harness, transferId);

    final offer = await receiver.nextOffer();
    expect(offer.transferId, transferId);
    expect(offer.files.map((file) => file.name), [
      'app.apk',
      'server.log',
      'empty.txt',
    ]);
    final download = receiver.accept(offer);
    final events = download.events.toList();
    await download.done;

    expect(await outcome, isA<OutgoingTransferCompleted>());
    final completed = (await events).last as IncomingTransferCompleted;
    expect(completed.savedFiles, hasLength(3));
    expect(await completed.savedFiles.first.readAsBytes(), apkBytes);
    expect(
      await completed.savedFiles[1].readAsString(),
      'line one\nline two\n',
    );
    expect(await completed.savedFiles[2].length(), 0);
  });

  test('the laptop reports progress up to the full size', () async {
    final file = await harness.writeFile('video.mp4', _randomBytes(700000));
    final receiver = await _Phone.connect(harness);
    final sending = <int>[];
    harness.sender.events.listen((event) {
      final update = event.update;
      if (update is OutgoingTransferSending) sending.add(update.bytesSent);
    });
    final transferId = harness.sender.offerFiles(
      deviceId: phone.deviceId,
      files: [file],
    );
    final outcome = _outcomeOf(harness, transferId);

    await receiver.accept(await receiver.nextOffer()).done;
    await outcome;

    expect(sending.first, 0);
    expect(sending.last, 700000);
    expect(sending, orderedEquals([...sending]..sort()));
  });

  test('a declined offer ends as rejected', () async {
    final file = await harness.writeFile('a.txt', 'hello'.codeUnits);
    final receiver = await _Phone.connect(harness);
    final transferId = harness.sender.offerFiles(
      deviceId: phone.deviceId,
      files: [file],
    );
    final outcome = _outcomeOf(harness, transferId);

    final offer = await receiver.nextOffer();
    receiver.connection.send(TransferDecisionMessage.reject(offer.transferId));

    expect(await outcome, _failedWith(TransferFailure.rejected));
    expect(
      await _get(harness, '/v1/transfers/$transferId/0'),
      HttpStatus.notFound,
    );
  });

  test('an unanswered offer times out and is withdrawn', () async {
    final harness = await TransferHarness.start(
      decisionTimeout: const Duration(milliseconds: 100),
    );
    final file = await harness.writeFile('a.txt', 'hello'.codeUnits);
    final receiver = await _Phone.connect(harness);
    final withdrawn = receiver.connection.messages.firstWhere(
      (message) =>
          message is TransferDecisionMessage &&
          message.type == MessageType.cancel,
    );
    final transferId = harness.sender.offerFiles(
      deviceId: phone.deviceId,
      files: [file],
    );

    expect(
      await _outcomeOf(harness, transferId),
      _failedWith(TransferFailure.timedOut),
    );
    await withdrawn;
  });

  test("offering to a phone that isn't connected fails at once", () async {
    final file = await harness.writeFile('a.txt', 'hello'.codeUnits);

    expect(
      () => harness.sender.offerFiles(deviceId: phone.deviceId, files: [file]),
      throwsA(
        isA<TransferException>().having(
          (e) => e.failure,
          'failure',
          TransferFailure.unreachable,
        ),
      ),
    );
  });

  test('more files than one offer may carry are refused locally', () async {
    final file = await harness.writeFile('a.txt', 'hello'.codeUnits);
    final receiver = await _Phone.connect(harness);

    expect(
      () => harness.sender.offerFiles(
        deviceId: phone.deviceId,
        files: List.filled(ProtocolLimits.maxFilesPerOffer + 1, file),
      ),
      throwsA(
        isA<TransferException>().having(
          (e) => e.failure,
          'failure',
          TransferFailure.tooManyFiles,
        ),
      ),
    );
    await pumpEventQueue();
    expect(receiver.connection.isOpen, isTrue);
  });

  test('an offer with no files is refused locally', () async {
    await _Phone.connect(harness);

    expect(
      () => harness.sender.offerFiles(deviceId: phone.deviceId, files: []),
      throwsA(
        isA<TransferException>().having(
          (e) => e.failure,
          'failure',
          TransferFailure.noFiles,
        ),
      ),
    );
  });

  test('a local name the protocol forbids is cleaned in the offer', () async {
    final file = OutgoingFile(
      name: 'bad\nname.txt',
      sizeBytes: 0,
      mimeType: 'text/plain',
      openRead: () => const Stream.empty(),
    );
    final receiver = await _Phone.connect(harness);
    harness.sender.offerFiles(deviceId: phone.deviceId, files: [file]);

    expect((await receiver.nextOffer()).files.single.name, 'bad_name.txt');
  });

  test('the laptop can cancel mid-download', () async {
    final slow = _slowFile(1 << 20);
    final receiver = await _Phone.connect(harness);
    final transferId = harness.sender.offerFiles(
      deviceId: phone.deviceId,
      files: [slow.file],
    );
    final outcome = _outcomeOf(harness, transferId);
    final download = receiver.accept(await receiver.nextOffer());
    final events = download.events.toList();
    slow.bytes.add(_randomBytes(1000));
    await pumpEventQueue();

    harness.sender.cancel(transferId);
    await download.done;

    expect(await outcome, _failedWith(TransferFailure.cancelled));
    expect((await events).last, _endedWith(TransferFailure.cancelled));
    expect(receiver.savedFiles(), isEmpty);
  });

  test('the phone can cancel mid-download', () async {
    final slow = _slowFile(1 << 20);
    final receiver = await _Phone.connect(harness);
    final transferId = harness.sender.offerFiles(
      deviceId: phone.deviceId,
      files: [slow.file],
    );
    final outcome = _outcomeOf(harness, transferId);
    final download = receiver.accept(await receiver.nextOffer());
    final events = download.events.toList();
    slow.bytes.add(_randomBytes(1000));
    await pumpEventQueue();

    download.cancel();
    await download.done;

    expect(await outcome, _failedWith(TransferFailure.cancelled));
    expect((await events).last, _endedWith(TransferFailure.cancelled));
    expect(receiver.savedFiles(), isEmpty);
  });

  test('a source file that shrinks is never saved on the phone', () async {
    final shrunk = OutgoingFile(
      name: 'shrunk.bin',
      sizeBytes: 5000,
      mimeType: 'application/octet-stream',
      openRead: () => Stream.value(_randomBytes(1200)),
    );
    final receiver = await _Phone.connect(harness);
    final transferId = harness.sender.offerFiles(
      deviceId: phone.deviceId,
      files: [shrunk],
    );
    final outcome = _outcomeOf(harness, transferId);
    final download = receiver.accept(await receiver.nextOffer());
    final events = download.events.toList();
    await download.done;

    expect(await outcome, _failedWith(TransferFailure.unreadableFile));
    expect((await events).last, isA<IncomingTransferEnded>());
    expect(receiver.savedFiles(), isEmpty);
  });

  group('downloads', () {
    late String transferId;
    late _Phone receiver;

    setUp(() async {
      final file = await harness.writeFile('secret.txt', 'secret'.codeUnits);
      receiver = await _Phone.connect(harness);
      transferId = harness.sender.offerFiles(
        deviceId: phone.deviceId,
        files: [file],
      );
      await receiver.nextOffer();
    });

    void accept() {
      receiver.connection.send(TransferDecisionMessage.accept(transferId));
    }

    test('are refused without valid pairing credentials', () async {
      accept();
      await pumpEventQueue();
      final wrongToken = buildAuthHeaders(
        localDeviceId: phone.deviceId,
        authToken: 'auth_wrongwrongwrongwrongwrongwrong00',
      );

      expect(
        await _get(harness, '/v1/transfers/$transferId/0', headers: const {}),
        HttpStatus.unauthorized,
      );
      expect(
        await _get(harness, '/v1/transfers/$transferId/0', headers: wrongToken),
        HttpStatus.unauthorized,
      );
    });

    test("can't be taken by another paired device", () async {
      accept();
      await pumpEventQueue();

      expect(
        await _get(
          harness,
          '/v1/transfers/$transferId/0',
          headers: harness.authHeadersFor(otherPhone),
        ),
        HttpStatus.notFound,
      );
    });

    test("can't be accepted by another paired device", () async {
      final other = await harness.connect(otherPhone);
      other.send(TransferDecisionMessage.accept(transferId));
      await pumpEventQueue();

      expect(
        await _get(harness, '/v1/transfers/$transferId/0'),
        HttpStatus.conflict,
      );
    });

    test('are refused before the phone accepts', () async {
      expect(
        await _get(harness, '/v1/transfers/$transferId/0'),
        HttpStatus.conflict,
      );
    });

    test(
      'can be asked for again, but never past the end of the file',
      () async {
        accept();
        await pumpEventQueue();
        final path = '/v1/transfers/$transferId/0';
        Map<String, String> from(int offset) => {
          ...harness.authHeadersFor(phone),
          'x-sharely-offset': '$offset',
        };

        expect(await _get(harness, path), HttpStatus.ok);
        expect(await _get(harness, path, headers: from(6)), HttpStatus.ok);
        expect(
          await _get(harness, path, headers: from(7)),
          HttpStatus.badRequest,
        );
        expect(
          await _get(harness, path, headers: from(-1)),
          HttpStatus.badRequest,
        );
        expect(
          await _get(
            harness,
            path,
            headers: {...from(0), 'x-sharely-offset': 'x'},
          ),
          HttpStatus.badRequest,
        );
      },
    );

    test('of an unknown file index or transfer are refused', () async {
      accept();
      await pumpEventQueue();

      for (final path in [
        '/v1/transfers/$transferId/1',
        '/v1/transfers/$transferId/-1',
        '/v1/transfers/$transferId/abc',
        '/v1/transfers/unknown_0123456789ab/0',
      ]) {
        expect(await _get(harness, path), HttpStatus.notFound, reason: path);
      }
    });
  });

  group('the phone discards a download', () {
    final bytes = _randomBytes(4000);

    Future<IncomingTransferEvent> downloadFrom(DeviceEndpoint laptop) async {
      final receiver = await _Phone.connect(harness);
      final download = receiver.accept(_offerOf(bytes), endpoint: laptop);
      final events = download.events.toList();
      await download.done;
      expect(receiver.savedFiles(), isEmpty);
      return (await events).last;
    }

    test('whose checksum does not match', () async {
      final hasher = Xxh64Accumulator()..add([...bytes]..[10] ^= 1);
      final laptop = await _serveRawBody([
        ...bytes,
        ...encodeUploadChecksum(hasher.finish()),
      ]);

      expect(await downloadFrom(laptop), _endedWith(TransferFailure.corrupted));
    });

    test('whose declared length differs from the offer', () async {
      final laptop = await _serveRawBody([...bytes, ...bytes]);

      expect(await downloadFrom(laptop), _endedWith(TransferFailure.corrupted));
    });

    test('that stops before the checksum', () async {
      final laptop = await _serveRawBody(bytes, declared: bytes.length + 8);

      expect(await downloadFrom(laptop), isA<IncomingTransferEnded>());
    });
  });
}
