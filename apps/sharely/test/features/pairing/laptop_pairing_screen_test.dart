import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sharely/features/pairing/laptop_pairing_screen.dart';
import 'package:sharely/features/pairing/state/laptop_pairing_controller.dart';
import 'package:sharely/features/pairing/state/laptop_pairing_state.dart';
import 'package:sharely_core/sharely_core.dart';

class _FixedLaptopPairing extends LaptopPairingController {
  new(this._state);

  final LaptopPairingState _state;

  @override
  Future<LaptopPairingState> build() async => _state;
}

Future<void> _pumpLaptopScreen(
  WidgetTester tester,
  LaptopPairingState state,
) async {
  tester.view.physicalSize = const Size(1280, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        laptopPairingProvider.overrideWith(() => _FixedLaptopPairing(state)),
      ],
      child: const MaterialApp(home: LaptopPairingScreen()),
    ),
  );
  await tester.pump(const Duration(seconds: 1));
  // flutter_animate starts with a zero-length timer; flush it.
  await tester.pump(const Duration(milliseconds: 1));
}

void main() {
  testWidgets('waiting state shows the QR card and spaced code', (
    tester,
  ) async {
    await _pumpLaptopScreen(
      tester,
      LaptopWaitingForPhone(
        invite: PairingInvite(
          host: InternetAddress('192.168.1.24'),
          port: 53891,
          token: 'tok_0123456789abcdef',
          deviceId: 'laptop_0123456789ab',
          deviceName: 'Laptop',
        ),
        code: '482913',
        expiresAt: DateTime.now().add(const Duration(minutes: 5)),
      ),
    );

    expect(find.text('Waiting for a scan…'), findsOneWidget);
    expect(find.text('482 913'), findsOneWidget);
  });

  testWidgets('paired state names the phone and offers another pairing', (
    tester,
  ) async {
    await _pumpLaptopScreen(
      tester,
      LaptopPairedWithPhone(
        PairedDevice(
          deviceId: 'phone_0123456789abc',
          deviceName: "Satyam's Phone",
          platform: DevicePlatform.android,
          authToken: 'auth_0123456789abcdef',
          pairedAt: DateTime(2026, 10, 4),
        ),
      ),
    );

    expect(find.text("Satyam's Phone is ready"), findsOneWidget);
    expect(find.text('Start sending'), findsOneWidget);
    expect(find.text('Pair another device'), findsOneWidget);
  });
}
