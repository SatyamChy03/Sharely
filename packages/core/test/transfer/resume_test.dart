import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:sharely_core/sharely_core.dart';
import 'package:test/test.dart';

import 'transfer_harness.dart';

const int _chunkBytes = 64 * 1024;
const _retryDelay = Duration(milliseconds: 50);

final List<int> _videoBytes = () {
  final random = Random(11);
  return List.generate(3 * 1024 * 1024 + 17, (_) => random.nextInt(256));
}();

Stream<List<int>> _inChunks(List<int> bytes) async* {
  for (var start = 0; start < bytes.length; start += _chunkBytes) {
    yield bytes.sublist(start, min(start + _chunkBytes, bytes.length));
  }
}

/// A file whose first read stops after [goodBytes]: either with a network
/// error ([hangs] false) or by going silent, as a dead Wi-Fi link does.
({OutgoingFile file, int Function() reads}) _flakyFile({
  int goodBytes = 2 * 1024 * 1024,
  bool hangs = false,
}) {
  var reads = 0;
  Stream<List<int>> firstRead() async* {
    yield* _inChunks(_videoBytes.sublist(0, goodBytes));
    // Lets the bytes reach the other side before the link "drops".
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (hangs) await Completer<void>().future;
    throw const SocketException('Wi-Fi dropped');
  }

  final file = OutgoingFile(
    name: 'video.mp4',
    sizeBytes: _videoBytes.length,
    mimeType: 'video/mp4',
    openRead: () => ++reads == 1 ? firstRead() : _inChunks(_videoBytes),
  );
  return (file: file, reads: () => reads);
}

PeerReconnect _reconnectVia(TransferHarness harness) =>
    (timeout) async =>
        (connection: await harness.connect(), endpoint: harness.endpoint);

Matcher _failsWith(TransferFailure failure) => throwsA(
  isA<TransferException>().having((e) => e.failure, 'failure', failure),
);

/// The first progress report after "reconnecting", which shows where the
/// transfer picked up.
int _bytesAfterReconnect(List<OutgoingTransferUpdate> updates) {
  final paused = updates.lastIndexWhere(
    (update) => update is OutgoingTransferReconnecting,
  );
  expect(paused, isNot(-1), reason: 'never reported reconnecting');
  return updates
      .skip(paused)
      .whereType<OutgoingTransferSending>()
      .first
      .bytesSent;
}

/// Long enough for a flaky file's good bytes to cross and its link to stall.
Future<void> _untilPartlySent() =>
    Future<void>.delayed(const Duration(milliseconds: 600));

Future<void> _eventually(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) fail('Condition never became true');
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

void main() {
  group('phone to laptop', () {
    late TransferHarness harness;

    setUp(() async {
      harness = await TransferHarness.start()
        ..acceptEveryOffer();
    });

    OutgoingTransfer send(
      OutgoingFile file,
      ControlConnection connection, {
      PeerReconnect? reconnect,
      Duration resumeWindow = const Duration(seconds: 10),
    }) => OutgoingTransfer.start(
      files: [file],
      connection: connection,
      endpoint: harness.endpoint,
      authHeaders: harness.authHeadersFor(phone),
      reconnect: reconnect,
      resumeWindow: resumeWindow,
      retryDelay: _retryDelay,
    );

    test('an upload that breaks off continues where it stopped', () async {
      final flaky = _flakyFile();
      final interrupted = harness.receiver.events
          .whereType<IncomingTransferInterrupted>()
          .first;
      final transfer = send(flaky.file, await harness.connect());
      final updates = transfer.updates.toList();

      await transfer.done;

      await interrupted;
      expect(await harness.savedFiles().single.readAsBytes(), _videoBytes);
      expect(flaky.reads(), 2);
      // Resumed past the start: the laptop kept what it had received.
      expect(_bytesAfterReconnect(await updates), greaterThan(_chunkBytes));
      expect((await updates).last, isA<OutgoingTransferCompleted>());
    });

    test('three files in flight all resume after one reconnect', () async {
      final flaky = [for (var i = 0; i < 3; i++) _flakyFile(hangs: true)];
      final connection = await harness.connect();
      var reconnects = 0;
      final transfer = OutgoingTransfer.start(
        files: [for (final one in flaky) one.file],
        connection: connection,
        endpoint: harness.endpoint,
        authHeaders: harness.authHeadersFor(phone),
        reconnect: (timeout) {
          reconnects++;
          return _reconnectVia(harness)(timeout);
        },
        retryDelay: _retryDelay,
      );
      final updates = transfer.updates.toList();
      await _untilPartlySent();

      await connection.close();
      await transfer.done;

      final saved = harness.savedFiles();
      expect(saved, hasLength(3));
      for (final file in saved) {
        expect(await file.readAsBytes(), _videoBytes);
      }
      expect(reconnects, 1);
      final sent = (await updates).whereType<OutgoingTransferSending>();
      expect(sent.last.bytesSent, transfer.totalBytes);
    });

    test('a send survives losing the whole connection', () async {
      final flaky = _flakyFile(hangs: true);
      final connection = await harness.connect();
      final transfer = send(
        flaky.file,
        connection,
        reconnect: _reconnectVia(harness),
      );
      final updates = transfer.updates.toList();
      await _untilPartlySent();

      await connection.close();
      await transfer.done;

      expect(await harness.savedFiles().single.readAsBytes(), _videoBytes);
      expect(await updates, contains(isA<OutgoingTransferReconnecting>()));
    });

    test('a laptop that never comes back fails the send', () async {
      final flaky = _flakyFile(hangs: true);
      final connection = await harness.connect();
      final transfer = send(
        flaky.file,
        connection,
        reconnect: (timeout) async {
          await Future<void>.delayed(timeout);
          return null;
        },
        resumeWindow: const Duration(milliseconds: 400),
      );
      await _untilPartlySent();

      await connection.close();

      await expectLater(transfer.done, _failsWith(TransferFailure.unreachable));
    });

    test('cancelling while reconnecting stops at once', () async {
      final flaky = _flakyFile(hangs: true);
      final connection = await harness.connect();
      final transfer = send(
        flaky.file,
        connection,
        reconnect: (timeout) => Completer<PeerLink?>().future,
      );
      final reconnecting = transfer.updates.firstWhere(
        (update) => update is OutgoingTransferReconnecting,
      );
      await _untilPartlySent();
      await connection.close();
      await reconnecting;

      transfer.cancel();

      await expectLater(transfer.done, _failsWith(TransferFailure.cancelled));
    });
  });

  test('the laptop discards a half-received file nobody resumes', () async {
    // The phone goes silent without closing anything, as it does when it
    // walks out of Wi-Fi range.
    final harness = await TransferHarness.start(
      resumeWindow: const Duration(milliseconds: 400),
      dataIdleTimeout: const Duration(milliseconds: 500),
    );
    harness.acceptEveryOffer();
    final ended = harness.receiver.events
        .whereType<IncomingTransferEnded>()
        .first;
    final connection = await harness.connect();
    final transfer = OutgoingTransfer.start(
      files: [_flakyFile(hangs: true).file],
      connection: connection,
      endpoint: harness.endpoint,
      authHeaders: harness.authHeadersFor(phone),
      retryDelay: _retryDelay,
    );
    unawaited(transfer.done.catchError((Object _) {}));
    await harness.receiver.events.whereType<IncomingTransferProgressed>().first;
    expect(harness.savedFiles(), hasLength(1));

    await connection.close();

    expect((await ended).reason, TransferFailure.unreachable);
    await _eventually(() => harness.savedFiles().isEmpty);
  });

  group('the resume point', () {
    late TransferHarness harness;
    const transferId = 'transfer_0123456789';
    final bytes = _videoBytes.sublist(0, 1000);

    setUp(() async {
      harness = await TransferHarness.start()
        ..acceptEveryOffer();
      (await harness.connect()).send(
        OfferMessage(
          transferId: transferId,
          files: [
            OfferedFile(
              name: 'a.bin',
              sizeBytes: bytes.length,
              mimeType: 'application/octet-stream',
            ),
          ],
        ),
      );
      await harness.receiver.events.whereType<IncomingOfferReceived>().first;
      await pumpEventQueue();
    });

    Future<ResumePointAnswer> ask(PairedDevice device, {String index = '0'}) =>
        _askOffset(harness, '/v1/transfers/$transferId/$index/offset', device);

    test('starts at zero and is only told to the sending phone', () async {
      expect(await ask(phone), (
        status: 200,
        body: '{"bytes":0,"saved":false}',
      ));
      expect((await ask(otherPhone)).status, HttpStatus.notFound);
      expect((await ask(phone, index: '5')).status, HttpStatus.notFound);
      expect(
        (await _askOffset(
          harness,
          '/v1/transfers/$transferId/0/offset',
          null,
        )).status,
        HttpStatus.unauthorized,
      );
    });

    test(
      'an upload from the wrong byte is refused and harms nothing',
      () async {
        final status = await _putFrom(harness, transferId, bytes, offset: 400);

        expect(status, HttpStatus.conflict);
        expect(await ask(phone), (
          status: 200,
          body: '{"bytes":0,"saved":false}',
        ));
        expect(harness.savedFiles(), isEmpty);
      },
    );
  });

  group('laptop to phone', () {
    late TransferHarness harness;
    late Directory downloads;

    setUp(() async {
      harness = await TransferHarness.start();
      downloads = Directory('${harness.workDirectory.path}/phone-downloads');
    });

    Future<
      (
        IncomingDownload,
        Future<OutgoingTransferUpdate>,
        List<OutgoingTransferUpdate>,
      )
    >
    receive(
      OutgoingFile file,
      ControlConnection connection, {
      PeerReconnect? reconnect,
      Duration resumeWindow = const Duration(seconds: 10),
    }) async {
      final offers = connection.messages
          .where((message) => message is OfferMessage)
          .cast<OfferMessage>()
          .first;
      final transferId = harness.sender.offerFiles(
        deviceId: phone.deviceId,
        files: [file],
      );
      final updates = <OutgoingTransferUpdate>[];
      final outcome = Completer<OutgoingTransferUpdate>();
      harness.sender.events.listen((event) {
        if (event.transferId != transferId) return;
        updates.add(event.update);
        final update = event.update;
        final isOver =
            update is OutgoingTransferCompleted ||
            update is OutgoingTransferFailed;
        if (isOver && !outcome.isCompleted) outcome.complete(update);
      });
      final download = IncomingDownload.start(
        offer: await offers,
        connection: connection,
        endpoint: harness.endpoint,
        authHeaders: harness.authHeadersFor(phone),
        saveDirectory: () async => downloads,
        reconnect: reconnect,
        resumeWindow: resumeWindow,
        retryDelay: _retryDelay,
      );
      return (download, outcome.future, updates);
    }

    List<File> saved() => downloads.existsSync()
        ? downloads.listSync().whereType<File>().toList()
        : const [];

    test('a download that breaks off continues where it stopped', () async {
      final flaky = _flakyFile();
      final (download, outcome, updates) = await receive(
        flaky.file,
        await harness.connect(),
      );
      final events = download.events.toList();

      await download.done;

      expect(await outcome, isA<OutgoingTransferCompleted>());
      expect((await events).last, isA<IncomingTransferCompleted>());
      expect(await events, contains(isA<IncomingTransferInterrupted>()));
      expect(await saved().single.readAsBytes(), _videoBytes);
      expect(_bytesAfterReconnect(updates), greaterThan(_chunkBytes));
    });

    test('a download survives losing the whole connection', () async {
      final flaky = _flakyFile(hangs: true);
      final connection = await harness.connect();
      final (download, outcome, updates) = await receive(
        flaky.file,
        connection,
        reconnect: _reconnectVia(harness),
      );
      final events = download.events.toList();
      await _untilPartlySent();

      await connection.close();
      await download.done;

      expect(await outcome, isA<OutgoingTransferCompleted>());
      expect((await events).last, isA<IncomingTransferCompleted>());
      expect(await saved().single.readAsBytes(), _videoBytes);
      expect(updates, contains(isA<OutgoingTransferReconnecting>()));
    });

    test('a phone that never comes back fails on both sides', () async {
      harness = await TransferHarness.start(
        resumeWindow: const Duration(milliseconds: 400),
      );
      downloads = Directory('${harness.workDirectory.path}/phone-downloads');
      final connection = await harness.connect();
      final (download, outcome, updates) = await receive(
        _flakyFile(hangs: true).file,
        connection,
        resumeWindow: const Duration(milliseconds: 400),
      );
      final events = download.events.toList();
      await _untilPartlySent();

      await connection.close();
      await download.done;

      expect(
        (await events).last,
        isA<IncomingTransferEnded>().having(
          (e) => e.reason,
          'reason',
          TransferFailure.unreachable,
        ),
      );
      expect(
        await outcome,
        isA<OutgoingTransferFailed>().having(
          (u) => u.reason,
          'reason',
          TransferFailure.unreachable,
        ),
      );
      expect(updates, contains(isA<OutgoingTransferReconnecting>()));
      expect(saved(), isEmpty);
    });
  });
}

typedef ResumePointAnswer = ({int status, String body});

Future<ResumePointAnswer> _askOffset(
  TransferHarness harness,
  String path,
  PairedDevice? device,
) async {
  final client = harness.endpoint.createHttpClient();
  try {
    final request = await client.getUrl(harness.endpoint.httpsUri(path));
    if (device != null) {
      harness.authHeadersFor(device).forEach(request.headers.set);
    }
    final response = await request.close();
    final body = await response
        .transform(const SystemEncoding().decoder)
        .join();
    return (status: response.statusCode, body: body);
  } finally {
    client.close(force: true);
  }
}

Future<int> _putFrom(
  TransferHarness harness,
  String transferId,
  List<int> bytes, {
  required int offset,
}) async {
  final client = harness.endpoint.createHttpClient();
  try {
    final request = await client.putUrl(
      harness.endpoint.httpsUri('/v1/transfers/$transferId/0'),
    );
    harness.authHeadersFor(phone).forEach(request.headers.set);
    request.headers.set('x-sharely-offset', offset);
    request.add(bytes.sublist(offset));
    final response = await request.close();
    await response.drain<void>();
    return response.statusCode;
  } finally {
    client.close(force: true);
  }
}
