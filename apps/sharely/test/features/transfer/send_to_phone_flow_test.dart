import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sharely/app/storage/trust_store_provider.dart';
import 'package:sharely/features/pairing/state/local_identity.dart';
import 'package:sharely/features/pairing/state/paired_devices.dart';
import 'package:sharely/features/transfer/state/file_picking.dart';
import 'package:sharely/features/transfer/state/incoming_transfer_view.dart';
import 'package:sharely/features/transfer/state/laptop_connection_controller.dart';
import 'package:sharely/features/transfer/state/laptop_connection_state.dart';
import 'package:sharely/features/transfer/state/laptop_offers_controller.dart';
import 'package:sharely/features/transfer/state/outgoing_file_collector.dart';
import 'package:sharely/features/transfer/state/phone_save_directory.dart';
import 'package:sharely/features/transfer/state/phone_send_controller.dart';
import 'package:sharely/features/transfer/state/quick_text_result.dart';
import 'package:sharely/features/transfer/state/received_note.dart';
import 'package:sharely/features/transfer/state/received_notes.dart';
import 'package:sharely/features/transfer/state/recent_transfer.dart';
import 'package:sharely/features/transfer/state/recent_transfers.dart';
import 'package:sharely/features/transfer/state/send_controller.dart';
import 'package:sharely/features/transfer/state/send_state.dart';
import 'package:sharely/features/transfer/state/transfer_receiver_provider.dart';
import 'package:sharely/features/transfer/state/transfer_sender_provider.dart';
import 'package:sharely_core/sharely_core.dart';

const _authToken = 'auth_0123456789abcdef0123456789abcdef';
const _phoneHello = HelloMessage(
  deviceId: 'phone_0123456789abc',
  deviceName: 'Phone',
  platform: DevicePlatform.android,
);
const _laptopHello = HelloMessage(
  deviceId: 'laptop_0123456789ab',
  deviceName: 'Laptop',
  platform: DevicePlatform.linux,
);
final List<int> _apkBytes = List.generate(300 * 1024, (index) => index % 249);

/// Resolves once [provider] reaches a state matching [isWanted].
Future<T> _waitFor<T>(
  ProviderContainer container,
  ProviderListenable<T> provider,
  bool Function(T state) isWanted,
) {
  final reached = Completer<T>();
  final subscription = container.listen<T>(provider, (_, next) {
    if (isWanted(next) && !reached.isCompleted) reached.complete(next);
  }, fireImmediately: true);
  return reached.future
      .timeout(const Duration(seconds: 10))
      .whenComplete(subscription.close);
}

bool _hasStage(List<IncomingTransferView> views, IncomingTransferStage stage) =>
    views.any((view) => view.stage == stage);

void main() {
  late Directory workDirectory;
  late ProviderContainer laptop;
  late ProviderContainer phone;

  Directory phoneDownloads() => Directory('${workDirectory.path}/downloads');

  setUp(() async {
    workDirectory = await Directory.systemTemp.createTemp('sharely_app_');
    final phoneRecord = PairedDevice.fromHello(
      _phoneHello,
      authToken: _authToken,
      pairedAt: DateTime.utc(2026, 10, 5),
    );
    laptop = ProviderContainer(
      overrides: [
        trustStoreProvider.overrideWithValue(TrustStore(MemorySecretStore())),
        saveDirectoryProvider.overrideWithValue(
          () async => Directory('${workDirectory.path}/received'),
        ),
        folderPickerProvider.overrideWithValue(
          () async => '${workDirectory.path}/project',
        ),
      ],
    );
    await laptop.read(pairedDevicesProvider.notifier).trust(phoneRecord);
    final server = await SharelyServer.start(
      address: InternetAddress.loopbackIPv4,
      preferredPort: 0,
      pairingHandler: PairingRequestHandler(
        currentSession: () => null,
        localHello: _laptopHello,
        onPaired: (_) {},
      ),
      transfers: (
        receiver: laptop.read(transferReceiverProvider),
        sender: laptop.read(transferSenderProvider),
        findPairedDevice: (deviceId) =>
            deviceId == phoneRecord.deviceId ? phoneRecord : null,
      ),
    );
    phone = ProviderContainer(
      overrides: [
        trustStoreProvider.overrideWithValue(TrustStore(MemorySecretStore())),
        localHelloProvider.overrideWith((ref) async => _phoneHello),
        phoneSaveDirectoryProvider.overrideWithValue(
          () async => phoneDownloads(),
        ),
      ],
    );
    addTearDown(() async {
      phone.dispose();
      laptop.dispose();
      await server.stop();
      await workDirectory.delete(recursive: true);
    });
    await phone
        .read(pairedDevicesProvider.notifier)
        .trust(
          PairedDevice.fromHello(
            _laptopHello,
            authToken: _authToken,
            pairedAt: DateTime.utc(2026, 10, 5),
            endpoint: DeviceEndpoint(host: server.address, port: server.port),
          ),
        );
    // Reading these starts the phone listening, as its Home screen does.
    phone
      ..listen(laptopOffersProvider, (_, _) {})
      ..listen(receivedNotesProvider, (_, _) {});
    laptop.listen(phoneNotesProvider, (_, _) {});
    await _waitFor<LaptopConnectionState>(
      phone,
      laptopConnectionProvider,
      (state) => state is LaptopConnected,
    );
    await pumpEventQueue();
  });

  Future<String> writeFile(String relativePath, List<int> bytes) async {
    final file = File('${workDirectory.path}/$relativePath');
    await file.create(recursive: true);
    await file.writeAsBytes(bytes);
    return file.path;
  }

  Future<IncomingTransferView> sendAndWaitForOffer(List<String> paths) async {
    final offered = _waitFor<List<IncomingTransferView>>(
      phone,
      laptopOffersProvider,
      (views) => _hasStage(views, IncomingTransferStage.offered),
    );
    await laptop.read(phoneSendProvider.notifier).sendPaths(paths);
    expect(laptop.read(phoneSendProvider), isA<SendAwaitingAcceptance>());
    return (await offered).single;
  }

  test('files sent from the laptop are saved on the phone', () async {
    final offer = await sendAndWaitForOffer([
      await writeFile('app-release.apk', _apkBytes),
      await writeFile('server.log', 'boot ok\n'.codeUnits),
    ]);
    expect(offer.fileNames, ['app-release.apk', 'server.log']);
    expect(offer.senderName, 'Laptop');

    phone.read(laptopOffersProvider.notifier).accept(offer.transferId);

    await _waitFor<SendState>(
      laptop,
      phoneSendProvider,
      (state) => state is SendSucceeded,
    );
    final saved = await _waitFor<List<IncomingTransferView>>(
      phone,
      laptopOffersProvider,
      (views) => _hasStage(views, IncomingTransferStage.saved),
    );
    expect(await saved.single.savedFiles.first.readAsBytes(), _apkBytes);
    expect(
      await File('${phoneDownloads().path}/server.log').readAsString(),
      'boot ok\n',
    );
    expect(
      phone.read(recentTransfersProvider).map((t) => (t.name, t.direction)),
      containsAll([
        ('app-release.apk', TransferDirection.received),
        ('server.log', TransferDirection.received),
      ]),
    );
    expect(
      laptop.read(recentTransfersProvider).map((t) => t.direction).toSet(),
      {TransferDirection.sent},
    );
  });

  test('a chosen folder sends the files inside it', () async {
    await writeFile('project/readme.md', 'hi'.codeUnits);
    await writeFile('project/src/main.dart', 'void main() {}'.codeUnits);
    final offered = _waitFor<List<IncomingTransferView>>(
      phone,
      laptopOffersProvider,
      (views) => _hasStage(views, IncomingTransferStage.offered),
    );

    await laptop.read(phoneSendProvider.notifier).pickAndSendFolder();

    expect(
      (await offered).single.fileNames,
      unorderedEquals(['readme.md', 'main.dart']),
    );
  });

  test('an empty folder is explained instead of offered', () async {
    await Directory('${workDirectory.path}/project').create();

    await laptop.read(phoneSendProvider.notifier).pickAndSendFolder();

    expect(
      laptop.read(phoneSendProvider),
      isA<SendFailed>().having(
        (s) => s.reason,
        'reason',
        TransferFailure.noFiles,
      ),
    );
    expect(phone.read(laptopOffersProvider), isEmpty);
  });

  test('declining on the phone tells the laptop', () async {
    final offer = await sendAndWaitForOffer([
      await writeFile('a.txt', 'hello'.codeUnits),
    ]);

    phone.read(laptopOffersProvider.notifier).decline(offer.transferId);

    final failed = await _waitFor<SendState>(
      laptop,
      phoneSendProvider,
      (state) => state is SendFailed,
    );
    expect(
      failed,
      isA<SendFailed>().having(
        (s) => s.reason,
        'reason',
        TransferFailure.rejected,
      ),
    );
    expect(phone.read(laptopOffersProvider), isEmpty);
    expect(phoneDownloads().existsSync(), isFalse);
  });

  test("cancelling on the laptop withdraws the phone's prompt", () async {
    await sendAndWaitForOffer([await writeFile('a.txt', 'hello'.codeUnits)]);

    laptop.read(phoneSendProvider.notifier).cancel();

    await _waitFor<List<IncomingTransferView>>(
      phone,
      laptopOffersProvider,
      (views) => views.isEmpty,
    );
    expect(laptop.read(phoneSendProvider), isA<SendFailed>());
  });

  test('"always accept" skips the next prompt and keeps the link', () async {
    final first = await sendAndWaitForOffer([
      await writeFile('a.txt', 'one'.codeUnits),
    ]);
    phone
        .read(laptopOffersProvider.notifier)
        .accept(first.transferId, alwaysFromLaptop: true);
    await _waitFor<SendState>(
      laptop,
      phoneSendProvider,
      (state) => state is SendSucceeded,
    );
    laptop.read(phoneSendProvider.notifier).dismiss();

    await laptop.read(phoneSendProvider.notifier).sendPaths([
      await writeFile('b.txt', 'two'.codeUnits),
    ]);

    await _waitFor<SendState>(
      laptop,
      phoneSendProvider,
      (state) => state is SendSucceeded,
    );
    expect(await File('${phoneDownloads().path}/b.txt').readAsString(), 'two');
  });

  test('an OTP and a link typed on the laptop reach the phone', () async {
    final controller = laptop.read(phoneSendProvider.notifier);

    expect(controller.sendText('482913'), QuickTextResult.sent);
    expect(controller.sendText('https://example.com/x'), QuickTextResult.sent);

    final notes = await _waitFor<List<ReceivedNote>>(
      phone,
      receivedNotesProvider,
      (notes) => notes.length == 2,
    );
    expect(notes.first.link, Uri.parse('https://example.com/x'));
    expect(notes.last.text, '482913');
    expect(notes.last.link, isNull);

    phone.read(receivedNotesProvider.notifier).dismiss(notes.first.id);
    expect(phone.read(receivedNotesProvider).single.text, '482913');
  });

  test(
    'an OTP, a link and log lines sent from the phone reach the laptop',
    () async {
      final controller = phone.read(sendProvider.notifier);
      const log = 'E/flutter: boom\n  at main (app.dart:3)';

      expect(controller.sendText('771204'), QuickTextResult.sent);
      expect(
        controller.sendText('https://example.com/y'),
        QuickTextResult.sent,
      );
      expect(controller.sendText(log), QuickTextResult.sent);

      final notes = await _waitFor<List<ReceivedNote>>(
        laptop,
        phoneNotesProvider,
        (notes) => notes.length == 3,
      );
      expect(notes[0].text, log);
      expect(notes[1].link, Uri.parse('https://example.com/y'));
      expect(notes[2].text, '771204');
      expect(phone.read(receivedNotesProvider), isEmpty);
    },
  );

  test(
    'the phone refuses text that is empty, too long or has nowhere to go',
    () async {
      final controller = phone.read(sendProvider.notifier);

      expect(controller.sendText(''), QuickTextResult.empty);
      expect(
        controller.sendText('a' * (ProtocolLimits.maxTextChars + 1)),
        QuickTextResult.tooLong,
      );
      await laptop.read(transferReceiverProvider).hub.closeAll();
      await _waitFor<LaptopConnectionState>(
        phone,
        laptopConnectionProvider,
        (state) => state is! LaptopConnected,
      );
      expect(controller.sendText('hello'), QuickTextResult.notConnected);
    },
  );

  test('text is refused when empty, too long or the phone is away', () async {
    final controller = laptop.read(phoneSendProvider.notifier);

    expect(controller.sendText('   '), QuickTextResult.empty);
    expect(
      controller.sendText('a' * (ProtocolLimits.maxTextChars + 1)),
      QuickTextResult.tooLong,
    );
    final disconnected = laptop
        .read(transferReceiverProvider)
        .hub
        .disconnects
        .first;
    phone.dispose();
    await disconnected;
    expect(controller.sendText('hello'), QuickTextResult.notConnected);
  });

  test('folders are opened up and links inside them are skipped', () async {
    final inside = await writeFile('tree/a/one.txt', 'one'.codeUnits);
    await writeFile('tree/two.txt', 'two'.codeUnits);
    await writeFile('outside.txt', 'secret'.codeUnits);
    await Link('${workDirectory.path}/tree/link.txt')
        .create('${workDirectory.path}/outside.txt');

    final files = await collectOutgoingFiles([
      '${workDirectory.path}/tree',
      inside,
    ]);
    final capped = await collectOutgoingFiles([
      '${workDirectory.path}/tree',
    ], maxFiles: 1);

    expect(
      files.map((file) => file.name),
      unorderedEquals(['one.txt', 'two.txt', 'one.txt']),
    );
    expect(capped, hasLength(2));
  });
}
