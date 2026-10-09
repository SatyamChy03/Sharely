import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sharely/app/storage/trust_store_provider.dart';
import 'package:sharely/features/pairing/state/laptop_pairing_controller.dart';
import 'package:sharely/features/pairing/state/laptop_pairing_state.dart';
import 'package:sharely/features/pairing/state/local_identity.dart';
import 'package:sharely/features/pairing/state/paired_devices.dart';
import 'package:sharely_core/sharely_core.dart';

const _laptopHello = HelloMessage(
  deviceId: 'laptop_0123456789ab',
  deviceName: "Satyam's Laptop",
  platform: DevicePlatform.linux,
);
const _phoneHello = HelloMessage(
  deviceId: 'phone_0123456789abc',
  deviceName: "Satyam's Phone",
  platform: DevicePlatform.android,
);

ProviderContainer _laptopContainer({
  InternetAddress? address,
  SecretStore? secrets,
}) {
  final container = ProviderContainer(
    overrides: [
      lanAddressProvider.overrideWith((ref) async => address),
      localHelloProvider.overrideWith((ref) async => _laptopHello),
      trustStoreProvider.overrideWithValue(
        TrustStore(secrets ?? MemorySecretStore()),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('shows a QR invite, then trusts the phone that redeems it', () async {
    final container = _laptopContainer(address: InternetAddress.loopbackIPv4);
    final waiting = await container.read(
      laptopPairingProvider.future,
    ) as LaptopWaitingForPhone;
    expect(waiting.code, matches(RegExp(r'^\d{6}$')));

    final laptop = await const PairingClient().pair(
      invite: waiting.invite,
      localHello: _phoneHello,
    );

    expect(laptop.deviceId, _laptopHello.deviceId);
    final state = container.read(laptopPairingProvider).value;
    expect(state, isA<LaptopPairedWithPhone>());
    expect(
      container.read(pairedDevicesProvider).value?.single.deviceId,
      _phoneHello.deviceId,
    );
  });

  test('pairing happens over TLS with the certificate in the invite', () async {
    final secrets = MemorySecretStore();
    final container = _laptopContainer(
      address: InternetAddress.loopbackIPv4,
      secrets: secrets,
    );
    final waiting = await container.read(
      laptopPairingProvider.future,
    ) as LaptopWaitingForPhone;

    final identity = await TrustStore(secrets).loadOrCreateTlsIdentity();

    expect(waiting.invite.certFingerprint, identity.fingerprint);
    expect(waiting.invite.toUriString(), contains(identity.fingerprint));
  });

  test('removing a phone ends the connection it already had', () async {
    final container = _laptopContainer(address: InternetAddress.loopbackIPv4);
    final waiting = await container.read(
      laptopPairingProvider.future,
    ) as LaptopWaitingForPhone;
    final laptop = await const PairingClient().pair(
      invite: waiting.invite,
      localHello: _phoneHello,
    );
    final connection = await ControlConnection.connect(
      laptop.endpoint!,
      authHeaders: buildAuthHeaders(
        localDeviceId: _phoneHello.deviceId,
        authToken: laptop.authToken,
      ),
    );
    addTearDown(connection.close);

    await container
        .read(pairedDevicesProvider.notifier)
        .forget(_phoneHello.deviceId);

    await connection.done.timeout(const Duration(seconds: 5));
    await expectLater(
      ControlConnection.connect(
        laptop.endpoint!,
        authHeaders: buildAuthHeaders(
          localDeviceId: _phoneHello.deviceId,
          authToken: laptop.authToken,
        ),
      ),
      throwsA(isA<TransferException>()),
    );
  });

  test('after a restart it shows the phone it already trusts', () async {
    final secrets = MemorySecretStore();
    final firstRun = _laptopContainer(
      address: InternetAddress.loopbackIPv4,
      secrets: secrets,
    );
    final waiting = await firstRun.read(
      laptopPairingProvider.future,
    ) as LaptopWaitingForPhone;
    await const PairingClient().pair(
      invite: waiting.invite,
      localHello: _phoneHello,
    );
    await pumpEventQueue();
    firstRun.dispose();

    final secondRun = _laptopContainer(
      address: InternetAddress.loopbackIPv4,
      secrets: secrets,
    );
    final state = await secondRun.read(laptopPairingProvider.future);

    expect(state, isA<LaptopPairedWithPhone>());
    expect(
      (state as LaptopPairedWithPhone).phone.deviceId,
      _phoneHello.deviceId,
    );
  });

  test('a new code invalidates the previous QR token', () async {
    final container = _laptopContainer(address: InternetAddress.loopbackIPv4);
    final first = await container.read(
      laptopPairingProvider.future,
    ) as LaptopWaitingForPhone;
    container.read(laptopPairingProvider.notifier).showNewCode();
    final second =
        container.read(laptopPairingProvider).value! as LaptopWaitingForPhone;

    expect(second.invite.token, isNot(first.invite.token));
    await expectLater(
      const PairingClient().pair(invite: first.invite, localHello: _phoneHello),
      throwsA(isA<PairingException>()),
    );
  });

  test('without a LAN address it asks the user to join Wi-Fi', () async {
    final container = _laptopContainer();
    expect(
      await container.read(laptopPairingProvider.future),
      isA<LaptopNotOnNetwork>(),
    );
  });
}
