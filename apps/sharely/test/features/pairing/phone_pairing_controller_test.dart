import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sharely/features/pairing/state/local_identity.dart';
import 'package:sharely/features/pairing/state/paired_devices.dart';
import 'package:sharely/features/pairing/state/phone_pairing_controller.dart';
import 'package:sharely/features/pairing/state/phone_pairing_state.dart';
import 'package:sharely_core/sharely_core.dart';

const _validInvite =
    'sharely://pair?v=1&h=192.168.1.24&p=53891&t=tok_0123456789abcdef'
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

ProviderContainer _phoneContainer(Future<PairedDevice> Function() result) {
  final container = ProviderContainer(
    overrides: [
      pairingClientProvider.overrideWithValue(_FakePairingClient(result)),
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
    expect(container.read(pairedDevicesProvider).single, _laptop);
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
      expect(container.read(pairedDevicesProvider), isEmpty);
    });
  }
}
