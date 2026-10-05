import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:sharely_core/sharely_core.dart';
import 'package:test/test.dart';

import 'transfer_harness.dart';

List<int> _randomBytes(int length) {
  final random = Random(42);
  return List.generate(length, (_) => random.nextInt(256));
}

/// Waits for a condition that settles asynchronously, such as a file delete.
Future<void> _eventually(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) fail('Condition never became true');
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

Future<OutgoingTransfer> _startSending(
  TransferHarness harness,
  List<OutgoingFile> files, {
  Duration decisionTimeout = const Duration(seconds: 5),
}) async {
  return OutgoingTransfer.start(
    files: files,
    connection: await harness.connect(),
    endpoint: harness.endpoint,
    authHeaders: harness.authHeadersFor(phone),
    decisionTimeout: decisionTimeout,
  );
}

Matcher _failsWith(TransferFailure failure) => throwsA(
  isA<TransferException>().having((e) => e.failure, 'failure', failure),
);

void main() {
  late TransferHarness harness;

  setUp(() async => harness = await TransferHarness.start());

  test('an accepted transfer saves byte-identical files', () async {
    harness.acceptEveryOffer();
    final photoBytes = _randomBytes(300 * 1024);
    final files = [
      await harness.writeFile('photo.jpg', photoBytes),
      await harness.writeFile('note.txt', 'hello'.codeUnits),
    ];
    final completed = harness.receiver.events
        .whereType<IncomingTransferCompleted>()
        .first;

    final transfer = await _startSending(harness, files);
    final updates = transfer.updates.toList();
    await transfer.done;

    final saved = (await completed).savedFiles;
    expect(saved.map((file) => file.uri.pathSegments.last), [
      'photo.jpg',
      'note.txt',
    ]);
    expect(await saved.first.readAsBytes(), photoBytes);
    expect(await updates, [
      isA<OutgoingTransferPreparing>(),
      isA<OutgoingTransferPreparing>(),
      isA<OutgoingTransferAwaitingAcceptance>(),
      ...List.filled(
        (await updates).whereType<OutgoingTransferSending>().length,
        isA<OutgoingTransferSending>(),
      ),
      isA<OutgoingTransferCompleted>(),
    ]);
  });

  test('a rejected offer saves nothing', () async {
    harness.receiver.events.whereType<IncomingOfferReceived>().listen(
      (event) => harness.receiver.reject(event.transferId),
    );
    final file = await harness.writeFile('a.txt', 'secret'.codeUnits);

    final transfer = await _startSending(harness, [file]);

    await expectLater(transfer.done, _failsWith(TransferFailure.rejected));
    expect(harness.savedFiles(), isEmpty);
  });

  test('the sender can cancel while waiting for an answer', () async {
    final ended = harness.receiver.events
        .whereType<IncomingTransferEnded>()
        .first;
    final file = await harness.writeFile('a.txt', 'x'.codeUnits);
    final transfer = await _startSending(harness, [file]);
    await transfer.updates
        .whereType<OutgoingTransferAwaitingAcceptance>()
        .first;

    transfer.cancel();

    await expectLater(transfer.done, _failsWith(TransferFailure.cancelled));
    expect((await ended).reason, TransferFailure.cancelled);
  });

  test(
    'the laptop can cancel mid-upload and the partial file is removed',
    () async {
      harness.acceptEveryOffer();
      harness.receiver.events
          .whereType<IncomingTransferProgressed>()
          .first
          .then((event) => harness.receiver.cancel(event.transferId))
          .ignore();
      final big = await harness.writeFile('big.bin', _randomBytes(8 << 20));

      final transfer = await _startSending(harness, [big]);

      await expectLater(transfer.done, _failsWith(TransferFailure.cancelled));
      await _eventually(() => harness.savedFiles().isEmpty);
    },
  );

  test('an unanswered offer times out and is withdrawn', () async {
    final ended = harness.receiver.events
        .whereType<IncomingTransferEnded>()
        .first;
    final file = await harness.writeFile('a.txt', 'x'.codeUnits);

    final transfer = await _startSending(harness, [
      file,
    ], decisionTimeout: const Duration(milliseconds: 200));

    await expectLater(transfer.done, _failsWith(TransferFailure.timedOut));
    expect((await ended).reason, TransferFailure.cancelled);
  });

  test(
    'a sender losing its connection ends the transfer on the laptop',
    () async {
      final ended = harness.receiver.events
          .whereType<IncomingTransferEnded>()
          .first;
      final connection = await harness.connect();
      final file = await harness.writeFile('a.txt', 'x'.codeUnits);
      final transfer = OutgoingTransfer.start(
        files: [file],
        connection: connection,
        endpoint: harness.endpoint,
        authHeaders: harness.authHeadersFor(phone),
      );
      await harness.receiver.events.whereType<IncomingOfferReceived>().first;

      await connection.close();

      await expectLater(transfer.done, _failsWith(TransferFailure.unreachable));
      expect((await ended).reason, TransferFailure.unreachable);
    },
  );

  test('an unreadable file fails clearly before anything is offered', () async {
    final file = await harness.writeFile('gone.txt', 'x'.codeUnits);
    await File('${harness.workDirectory.path}/gone.txt').delete();

    final transfer = await _startSending(harness, [file]);

    await expectLater(
      transfer.done,
      _failsWith(TransferFailure.unreadableFile),
    );
  });
}
