import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sharely_core/sharely_core.dart';
import 'package:sharely_core/src/transfer/parallel_settings.dart';
import 'package:sharely_core/src/transfer/transfer_paths.dart';
import 'package:test/test.dart';

import 'transfer_harness.dart';

/// Files that are read only when the test lets them, so it can see how
/// many are in flight at once.
class _GatedFiles {
  new(int count)
    : gates = List.generate(count, (_) => Completer<void>()),
      contents = [
        for (var index = 0; index < count; index++)
          List.filled(2000 + index, index),
      ];

  final List<Completer<void>> gates;
  final List<List<int>> contents;
  final opened = <int>[];

  late final List<OutgoingFile> files = [
    for (var index = 0; index < gates.length; index++)
      OutgoingFile(
        name: 'file$index.bin',
        sizeBytes: contents[index].length,
        mimeType: 'application/octet-stream',
        openRead: () => _read(index),
      ),
  ];

  Stream<List<int>> _read(int index) async* {
    opened.add(index);
    await gates[index].future;
    yield contents[index];
  }

  void release(Iterable<int> indexes) {
    for (final index in indexes) {
      if (!gates[index].isCompleted) gates[index].complete();
    }
  }

  void releaseAll() => release(Iterable.generate(gates.length));

  Future<void> untilOpened(int count) async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (opened.length < count) {
      if (DateTime.now().isAfter(deadline)) fail('Only ${opened.length} read');
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    // Time for one more to start, if anything were going to start it.
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
}

List<String> _names(List<File> files) => [
  for (final file in files) p.basename(file.path),
];

void main() {
  late TransferHarness harness;

  setUp(() async => harness = await TransferHarness.start());

  group('phone to laptop', () {
    Future<OutgoingTransfer> send(
      List<OutgoingFile> files, {
      int parallelFiles = defaultParallelFiles,
    }) async {
      harness.acceptEveryOffer();
      return OutgoingTransfer.start(
        files: files,
        connection: await harness.connect(),
        endpoint: harness.endpoint,
        authHeaders: harness.authHeadersFor(phone),
        parallelFiles: parallelFiles,
      );
    }

    test('three files travel at once and all arrive in offer order', () async {
      final gated = _GatedFiles(7);
      final completed = harness.receiver.events
          .whereType<IncomingTransferCompleted>()
          .first;
      final transfer = await send(gated.files);
      final updates = transfer.updates.toList();

      await gated.untilOpened(3);
      expect(gated.opened, hasLength(3));
      // The later ones finish first.
      gated
        ..release([2, 1])
        ..releaseAll();
      await transfer.done;

      final saved = (await completed).savedFiles;
      expect(_names(saved), [for (var i = 0; i < 7; i++) 'file$i.bin']);
      for (final (index, file) in saved.indexed) {
        expect(await file.readAsBytes(), gated.contents[index]);
      }
      final sent = (await updates).whereType<OutgoingTransferSending>();
      expect(sent.last.bytesSent, transfer.totalBytes);
      expect(
        sent.every((update) => update.bytesSent <= transfer.totalBytes),
        isTrue,
      );
    });

    test('one at a time is still possible', () async {
      final gated = _GatedFiles(3);
      final transfer = await send(gated.files, parallelFiles: 1);

      await gated.untilOpened(1);
      expect(gated.opened, [0]);
      gated.releaseAll();

      await transfer.done;
      expect(harness.savedFiles(), hasLength(3));
    });

    test('asking for more than the limit is held to the limit', () async {
      final gated = _GatedFiles(12);
      final transfer = await send(gated.files, parallelFiles: 100);

      await gated.untilOpened(maxParallelFilesPerTransfer);
      expect(gated.opened, hasLength(maxParallelFilesPerTransfer));
      gated.releaseAll();

      await transfer.done;
    });

    test('one unreadable file stops the others and fails the send', () async {
      final gated = _GatedFiles(5);
      final files = [
        ...gated.files.take(2),
        OutgoingFile(
          name: 'gone.bin',
          sizeBytes: 10,
          mimeType: 'application/octet-stream',
          openRead: () =>
              Stream.error(const FileSystemException('Removed while sending')),
        ),
        ...gated.files.skip(2),
      ];
      final ended = harness.receiver.events
          .whereType<IncomingTransferEnded>()
          .first;

      final transfer = await send(files);

      await expectLater(
        transfer.done,
        throwsA(
          isA<TransferException>().having(
            (error) => error.failure,
            'failure',
            TransferFailure.unreadableFile,
          ),
        ),
      );
      expect((await ended).reason, TransferFailure.cancelled);
      // Nothing half-written is left behind.
      await pumpEventQueue();
      expect(harness.savedFiles(), isEmpty);
    });

    test('the laptop refuses more open uploads than the limit', () async {
      const fileCount = maxParallelFilesPerTransfer + 1;
      final offer = OfferMessage(
        transferId: 'transfer_0123456789',
        files: [
          for (var index = 0; index < fileCount; index++)
            OfferedFile(
              name: 'f$index.bin',
              sizeBytes: 1000,
              mimeType: 'application/octet-stream',
            ),
        ],
      );
      harness.acceptEveryOffer();
      final accepted = harness.receiver.events
          .whereType<IncomingOfferReceived>()
          .first;
      (await harness.connect()).send(offer);
      await accepted;
      final client = harness.endpoint.createHttpClient();
      addTearDown(() => client.close(force: true));

      Future<HttpClientRequest> openUpload(int index) async {
        final request = await client.putUrl(
          harness.endpoint.httpsUri(transferFilePath(offer.transferId, index)),
        );
        harness.authHeadersFor(phone).forEach(request.headers.set);
        request
          ..contentLength = 1008
          ..add(List.filled(10, 1));
        await request.flush();
        return request;
      }

      for (var index = 0; index < maxParallelFilesPerTransfer; index++) {
        await openUpload(index);
      }
      await pumpEventQueue();
      final oneTooMany = await openUpload(maxParallelFilesPerTransfer);
      oneTooMany.add(List.filled(998, 1));
      final response = await oneTooMany.close().timeout(
        const Duration(seconds: 5),
      );

      expect(response.statusCode, HttpStatus.serviceUnavailable);
    });
  });

  group('laptop to phone', () {
    Future<({ControlConnection connection, OfferMessage offer, String id})>
    offerToPhone(List<OutgoingFile> files) async {
      final connection = await harness.connect();
      final offers = connection.messages.where((m) => m is OfferMessage).first;
      final id = harness.sender.offerFiles(
        deviceId: phone.deviceId,
        files: files,
      );
      return (
        connection: connection,
        offer: await offers as OfferMessage,
        id: id,
      );
    }

    test('three files travel at once and are listed in offer order', () async {
      final gated = _GatedFiles(7);
      final offered = await offerToPhone(gated.files);
      final outcome = harness.sender.events.firstWhere(
        (event) =>
            event.update is OutgoingTransferCompleted ||
            event.update is OutgoingTransferFailed,
      );
      final download = IncomingDownload.start(
        offer: offered.offer,
        connection: offered.connection,
        endpoint: harness.endpoint,
        authHeaders: harness.authHeadersFor(phone),
        saveDirectory: () async =>
            Directory('${harness.workDirectory.path}/phone'),
      );
      final completed = download.events
          .where((event) => event is IncomingTransferCompleted)
          .cast<IncomingTransferCompleted>()
          .first;

      await gated.untilOpened(3);
      expect(gated.opened, hasLength(3));
      gated
        ..release([2, 1])
        ..releaseAll();
      await download.done;

      final saved = (await completed).savedFiles;
      expect(_names(saved), [for (var i = 0; i < 7; i++) 'file$i.bin']);
      for (final (index, file) in saved.indexed) {
        expect(await file.readAsBytes(), gated.contents[index]);
      }
      expect((await outcome).update, isA<OutgoingTransferCompleted>());
    });

    test('the laptop refuses more open downloads than the limit', () async {
      final gated = _GatedFiles(maxParallelFilesPerTransfer + 1);
      final offered = await offerToPhone(gated.files);
      offered.connection.send(TransferDecisionMessage.accept(offered.id));
      await pumpEventQueue();
      final client = harness.endpoint.createHttpClient();
      addTearDown(() {
        gated.releaseAll();
        client.close(force: true);
      });

      Future<HttpClientResponse> ask(int index) async {
        final request = await client.getUrl(
          harness.endpoint.httpsUri(transferFilePath(offered.id, index)),
        );
        harness.authHeadersFor(phone).forEach(request.headers.set);
        return await request.close();
      }

      for (var index = 0; index < maxParallelFilesPerTransfer; index++) {
        expect((await ask(index)).statusCode, HttpStatus.ok);
      }
      final oneTooMany = await ask(maxParallelFilesPerTransfer);

      expect(oneTooMany.statusCode, HttpStatus.serviceUnavailable);
    });
  });
}
