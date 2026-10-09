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
import 'package:sharely/features/transfer/state/incoming_transfers_controller.dart';
import 'package:sharely/features/transfer/state/laptop_connection_controller.dart';
import 'package:sharely/features/transfer/state/laptop_connection_state.dart';
import 'package:sharely/features/transfer/state/laptop_offers_controller.dart';
import 'package:sharely/features/transfer/state/phone_save_directory.dart';
import 'package:sharely/features/transfer/state/phone_send_controller.dart';
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
const int _chunkBytes = 64 * 1024;
final List<int> _videoBytes = List.generate(
  2 * 1024 * 1024 + 5,
  (index) => (index * 7) % 253,
);

Stream<List<int>> _inChunks(List<int> bytes) async* {
  for (var start = 0; start < bytes.length; start += _chunkBytes) {
    final end = start + _chunkBytes;
    yield bytes.sublist(start, end > bytes.length ? bytes.length : end);
  }
}

/// Picks one video whose first read goes silent half-way, as it does when
/// the Wi-Fi drops; every later read is complete.
class _StallingFilePicker extends SendFilePicker {
  int _reads = 0;

  @override
  Future<List<OutgoingFile>> pickFiles({bool photosOnly = false}) async => [
    OutgoingFile(
      name: 'video.mp4',
      sizeBytes: _videoBytes.length,
      mimeType: 'video/mp4',
      openRead: () => ++_reads == 1 ? _stallHalfWay() : _inChunks(_videoBytes),
    ),
  ];

  @override
  Future<void> releasePickedFiles() async {}

  Stream<List<int>> _stallHalfWay() async* {
    yield* _inChunks(_videoBytes.sublist(0, _videoBytes.length ~/ 2));
    await Completer<void>().future;
  }
}

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
      .timeout(const Duration(seconds: 15))
      .whenComplete(subscription.close);
}

void main() {
  late Directory workDirectory;
  late ProviderContainer laptop;
  late ProviderContainer phone;

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
        sendFilePickerProvider.overrideWithValue(_StallingFilePicker()),
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
        sendFilePickerProvider.overrideWithValue(_StallingFilePicker()),
        phoneSaveDirectoryProvider.overrideWithValue(
          () async => Directory('${workDirectory.path}/downloads'),
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
    phone.listen(laptopOffersProvider, (_, _) {});
    laptop.listen(incomingTransfersProvider, (_, _) {});
    await _waitFor<LaptopConnectionState>(
      phone,
      laptopConnectionProvider,
      (state) => state is LaptopConnected,
    );
    await pumpEventQueue();
  });

  /// Cuts the phone's link the way losing Wi-Fi does, mid-transfer.
  Future<void> dropConnection() async {
    // Long enough for the first half of the file to cross and then stall.
    await Future<void>.delayed(const Duration(milliseconds: 600));
    final connection = phone.read(laptopConnectionProvider);
    await (connection as LaptopConnected).connection.close();
  }

  test('a send from the phone resumes after the Wi-Fi drops', () async {
    final offered = _waitFor<List<IncomingTransferView>>(
      laptop,
      incomingTransfersProvider,
      (views) => views.isNotEmpty,
    );
    final sawReconnecting = _waitFor<SendState>(
      phone,
      sendProvider,
      (state) => state is SendInProgress && state.isReconnecting,
    );
    expect(await phone.read(sendProvider.notifier).pickAndSend(), isTrue);
    final offer = (await offered).single;
    laptop.read(incomingTransfersProvider.notifier).accept(offer.transferId);

    await dropConnection();

    await sawReconnecting;
    await _waitFor<SendState>(
      phone,
      sendProvider,
      (state) => state is SendSucceeded,
    );
    final saved = await _waitFor<List<IncomingTransferView>>(
      laptop,
      incomingTransfersProvider,
      (views) => views.single.stage == IncomingTransferStage.saved,
    );
    expect(await saved.single.savedFiles.single.readAsBytes(), _videoBytes);
    expect(
      Directory('${workDirectory.path}/received').listSync(),
      hasLength(1),
    );
  });

  test('a send from the laptop resumes after the Wi-Fi drops', () async {
    final offered = _waitFor<List<IncomingTransferView>>(
      phone,
      laptopOffersProvider,
      (views) => views.isNotEmpty,
    );
    final sawReconnecting = _waitFor<List<IncomingTransferView>>(
      phone,
      laptopOffersProvider,
      (views) => views.any((view) => view.isReconnecting),
    );
    await laptop.read(phoneSendProvider.notifier).pickAndSendFiles();
    final offer = (await offered).single;
    phone.read(laptopOffersProvider.notifier).accept(offer.transferId);

    await dropConnection();

    await sawReconnecting;
    await _waitFor<SendState>(
      laptop,
      phoneSendProvider,
      (state) => state is SendSucceeded,
    );
    final saved = await _waitFor<List<IncomingTransferView>>(
      phone,
      laptopOffersProvider,
      (views) => views.single.stage == IncomingTransferStage.saved,
    );
    expect(saved.single.isReconnecting, isFalse);
    expect(await saved.single.savedFiles.single.readAsBytes(), _videoBytes);
    expect(
      Directory('${workDirectory.path}/downloads').listSync(),
      hasLength(1),
    );
  });
}
