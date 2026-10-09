import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sharely/features/pairing/state/local_identity.dart';
import 'package:sharely/features/pairing/state/paired_devices.dart';
import 'package:sharely/features/transfer/state/file_picking.dart';
import 'package:sharely/features/transfer/state/has_received_file.dart';
import 'package:sharely/features/transfer/state/incoming_transfer_view.dart';
import 'package:sharely/features/transfer/state/incoming_transfers_controller.dart';
import 'package:sharely/features/transfer/state/laptop_connection_controller.dart';
import 'package:sharely/features/transfer/state/laptop_connection_state.dart';
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
final List<int> _photoBytes = List.generate(200 * 1024, (index) => index % 251);

class _FixedPairedDevices extends PairedDevicesNotifier {
  new(this._devices);

  final List<PairedDevice> _devices;

  @override
  Future<List<PairedDevice>> build() async => _devices;
}

class _FakeFilePicker extends SendFilePicker {
  @override
  Future<List<OutgoingFile>> pickFiles({bool photosOnly = false}) async => [
    OutgoingFile(
      name: 'photo.jpg',
      sizeBytes: _photoBytes.length,
      mimeType: 'image/jpeg',
      openRead: () => Stream.value(_photoBytes),
    ),
  ];

  @override
  Future<void> releasePickedFiles() async {}
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
      .timeout(const Duration(seconds: 10))
      .whenComplete(subscription.close);
}

void main() {
  late Directory workDirectory;
  late ProviderContainer laptop;
  late ProviderContainer phone;

  setUp(() async {
    workDirectory = await Directory.systemTemp.createTemp('sharely_app_');
    laptop = ProviderContainer(
      overrides: [
        saveDirectoryProvider.overrideWithValue(
          () async => Directory('${workDirectory.path}/received'),
        ),
      ],
    );
    final phoneRecord = PairedDevice.fromHello(
      _phoneHello,
      authToken: _authToken,
      pairedAt: DateTime.utc(2026, 10, 5),
    );
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
    final laptopRecord = PairedDevice.fromHello(
      _laptopHello,
      authToken: _authToken,
      pairedAt: DateTime.utc(2026, 10, 5),
      endpoint: DeviceEndpoint(host: server.address, port: server.port),
    );
    phone = ProviderContainer(
      overrides: [
        pairedDevicesProvider.overrideWith(
          () => _FixedPairedDevices([laptopRecord]),
        ),
        localHelloProvider.overrideWith((ref) async => _phoneHello),
        sendFilePickerProvider.overrideWithValue(_FakeFilePicker()),
      ],
    );
    addTearDown(() async {
      phone.dispose();
      laptop.dispose();
      await server.stop();
      await workDirectory.delete(recursive: true);
    });
    await phone.read(pairedDevicesProvider.future);
    await _waitFor<LaptopConnectionState>(
      phone,
      laptopConnectionProvider,
      (state) => state is LaptopConnected,
    );
  });

  Future<IncomingTransferView> sendPhotoAndWaitForOffer() async {
    final offered = _waitFor<List<IncomingTransferView>>(
      laptop,
      incomingTransfersProvider,
      (views) {
        return views.any((view) => view.stage == IncomingTransferStage.offered);
      },
    );
    expect(await phone.read(sendProvider.notifier).pickAndSend(), isTrue);
    return (await offered).single;
  }

  test('a photo picked on the phone is saved on the laptop', () async {
    final offer = await sendPhotoAndWaitForOffer();
    expect(offer.fileNames, ['photo.jpg']);
    expect(offer.senderName, 'Phone');

    laptop.read(incomingTransfersProvider.notifier).accept(offer.transferId);

    await _waitFor<SendState>(
      phone,
      sendProvider,
      (state) => state is SendSucceeded,
    );
    final saved = await _waitFor<List<IncomingTransferView>>(
      laptop,
      incomingTransfersProvider,
      (views) {
        return views.single.stage == IncomingTransferStage.saved;
      },
    );
    expect(await saved.single.savedFiles.single.readAsBytes(), _photoBytes);
    expect(laptop.read(hasReceivedFileProvider), isTrue);
  });

  test('declining on the laptop tells the phone', () async {
    final offer = await sendPhotoAndWaitForOffer();

    laptop.read(incomingTransfersProvider.notifier).decline(offer.transferId);

    final failed = await _waitFor<SendState>(
      phone,
      sendProvider,
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
    expect(laptop.read(incomingTransfersProvider), isEmpty);
  });
}
