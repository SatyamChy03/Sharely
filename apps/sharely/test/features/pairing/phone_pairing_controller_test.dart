import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sharely/app/storage/trust_store_provider.dart';
import 'package:sharely/features/pairing/state/local_identity.dart';
import 'package:sharely/features/pairing/state/paired_devices.dart';
import 'package:sharely/features/pairing/state/phone_pairing_controller.dart';
import 'package:sharely/features/pairing/state/phone_pairing_state.dart';
import 'package:sharely_core/sharely_core.dart';

const _validInvite =
    'sharely://pair?v=2&h=192.168.1.24&p=53891&t=tok_0123456789abcdef'
    '&f=GC7sBY-wnhn-hzeInIlX3XANDNAagCm_dWCmPH5UdVQ'
    '&id=laptop_0123456789ab&n=Laptop';

final _laptop = PairedDevice(
  deviceId: 'laptop_0123456789ab',
  deviceName: 'Laptop',
  platform: DevicePlatform.windows,
  authToken: 'auth_0123456789abcdef',
  pairedAt: DateTime(2026, 10, 4),
);

class _FakePairingClient extends PairingClient {
  new(this._result);

  final Future<PairedDevice> Function() _result;

  @override
  Future<PairedDevice> pair({
    required PairingInvite invite,
    required HelloMessage localHello,
  }) => _result();
}

ProviderContainer _phoneContainer(
  Future<PairedDevice> Function() result, {
  SecretStore? secrets,
}) {
  final container = ProviderContainer(
    overrides: [
      pairingClientProvider.overrideWithValue(_FakePairingClient(result)),
      trustStoreProvider.overrideWithValue(
        TrustStore(secrets ?? MemorySecretStore()),
      ),
      localHelloProvider.overrideWith(
        (ref) async => const HelloMessage(
          deviceId: 'phone_0123456789abc',
          deviceName: 'Phone',
          platform: DevicePlatform.android,
        ),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('a valid invite pairs and trusts the laptop', () async {
    final container = _phoneContainer(() async => _laptop);
    await container
        .read(phonePairingProvider.notifier)
        .pairWithScannedCode(_validInvite);

    expect(container.read(phonePairingProvider), isA<PhonePaired>());
    expect(container.read(pairedDevicesProvider).value?.single, _laptop);
  });

  test('a paired laptop is still trusted after a restart', () async {
    final secrets = MemorySecretStore();
    final firstRun = _phoneContainer(() async => _laptop, secrets: secrets);
    await firstRun
        .read(phonePairingProvider.notifier)
        .pairWithScannedCode(_validInvite);
    firstRun.dispose();

    final secondRun = _phoneContainer(() async => _laptop, secrets: secrets);
    final trusted = await secondRun.read(pairedDevicesProvider.future);

    expect(trusted.single.deviceId, _laptop.deviceId);
    expect(trusted.single.authToken, _laptop.authToken);
  });

  final failures = {
    'a non-Sharely QR code': (
      'https://example.com',
      PhonePairingIssue.notSharelyCode,
    ),
    'an unreachable laptop': (_validInvite, PhonePairingIssue.unreachable),
  };
  for (final MapEntry(key: description, value: (code, issue))
      in failures.entries) {
    test('$description reports $issue', () async {
      final container = _phoneContainer(
        () => throw const PairingException(PairingFailure.unreachable),
      );
      await container
          .read(phonePairingProvider.notifier)
          .pairWithScannedCode(code);
      final state = container.read(phonePairingProvider);
      expect((state as PhonePairingFailed).issue, issue);
      expect(await container.read(pairedDevicesProvider.future), isEmpty);
    });
  }
}
