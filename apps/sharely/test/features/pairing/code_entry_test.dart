import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sharely/app/storage/trust_store_provider.dart';
import 'package:sharely/features/pairing/code_entry_screen.dart';
import 'package:sharely/features/pairing/state/local_identity.dart';
import 'package:sharely/features/pairing/state/phone_pairing_controller.dart';
import 'package:sharely/features/pairing/state/phone_pairing_state.dart';
import 'package:sharely_core/sharely_core.dart';

FoundLaptop _laptopAt(String host, String name) => (
  endpoint: DeviceEndpoint(host: InternetAddress(host), port: 53891),
  hello: HelloMessage(
    deviceId: 'laptop_${host.replaceAll('.', '')}_000000',
    deviceName: name,
    platform: DevicePlatform.windows,
  ),
);

class _FakeFinder extends LaptopFinder {
  const new(this._laptops);

  final List<FoundLaptop> _laptops;

  @override
  Future<List<FoundLaptop>> findOnLocalNetwork() async => _laptops;
}

class _RecordingClient extends PairingClient {
  PairingInvite? lastInvite;

  @override
  Future<PairedDevice> pair({
    required PairingInvite invite,
    required HelloMessage localHello,
  }) async {
    lastInvite = invite;
    return PairedDevice(
      deviceId: invite.deviceId,
      deviceName: invite.deviceName,
      platform: DevicePlatform.windows,
      authToken: 'auth_0123456789abcdef',
      pairedAt: DateTime.utc(2026, 10, 5),
    );
  }
}

ProviderContainer _phoneWith(List<FoundLaptop> laptops, PairingClient client) {
  final container = ProviderContainer(
    overrides: [
      laptopFinderProvider.overrideWithValue(_FakeFinder(laptops)),
      pairingClientProvider.overrideWithValue(client),
      trustStoreProvider.overrideWithValue(TrustStore(MemorySecretStore())),
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
  test('a typed code pairs with the one laptop on the Wi-Fi', () async {
    final client = _RecordingClient();
    final phone = _phoneWith([_laptopAt('192.168.1.24', 'Laptop')], client);

    await phone.read(phonePairingProvider.notifier).pairWithTypedCode('482913');

    expect(phone.read(phonePairingProvider), isA<PhonePaired>());
    expect(client.lastInvite?.token, '482913');
    expect(client.lastInvite?.host.address, '192.168.1.24');
  });

  test('with several laptops the code waits until the user picks', () async {
    final client = _RecordingClient();
    final phone = _phoneWith([
      _laptopAt('192.168.1.24', 'Work laptop'),
      _laptopAt('192.168.1.30', 'Home laptop'),
    ], client);

    await phone.read(phonePairingProvider.notifier).pairWithTypedCode('482913');

    expect(phone.read(phonePairingProvider), isA<PhoneChoosingLaptop>());
    expect(client.lastInvite, isNull);
  });

  test('no laptop on the Wi-Fi is reported plainly', () async {
    final phone = _phoneWith(const [], _RecordingClient());

    await phone.read(phonePairingProvider.notifier).pairWithTypedCode('482913');

    final state = phone.read(phonePairingProvider);
    expect(
      (state as PhonePairingFailed).issue,
      PhonePairingIssue.noLaptopFound,
    );
  });

  test('anything but six digits is ignored', () async {
    final client = _RecordingClient();
    final phone = _phoneWith([_laptopAt('192.168.1.24', 'Laptop')], client);

    await phone.read(phonePairingProvider.notifier).pairWithTypedCode('48291');

    expect(phone.read(phonePairingProvider), isA<PhoneReadyToScan>());
    expect(client.lastInvite, isNull);
  });

  testWidgets('Connect unlocks only once six digits are typed', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: CodeEntryScreen())),
    );
    TextButton pairButton() => tester.widget<TextButton>(
      find.ancestor(
        of: find.text('Connect'),
        matching: find.byType(TextButton),
      ),
    );

    expect(find.text('Enter pairing code'), findsOneWidget);
    expect(pairButton().onPressed, isNull);

    await tester.enterText(find.byType(TextField), '482913');
    await tester.pump();

    expect(find.text('9'), findsOneWidget);
    expect(pairButton().onPressed, isNotNull);
  });
}
