import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:sharely/app/routes.dart';
import 'package:sharely/features/laptop/laptop_devices_view.dart';
import 'package:sharely/features/laptop/laptop_home_screen.dart';
import 'package:sharely/features/pairing/laptop_pairing_screen.dart';
import 'package:sharely/features/pairing/state/laptop_pairing_controller.dart';
import 'package:sharely/features/pairing/state/laptop_pairing_state.dart';
import 'package:sharely/features/pairing/state/paired_devices.dart';
import 'package:sharely/features/transfer/state/connected_phones.dart';
import 'package:sharely/features/transfer/state/incoming_transfer_view.dart';
import 'package:sharely/features/transfer/state/incoming_transfers_controller.dart';
import 'package:sharely_core/sharely_core.dart';

PairedDevice _phone(String deviceId, String name) => PairedDevice(
  deviceId: deviceId,
  deviceName: name,
  platform: DevicePlatform.android,
  authToken: 'auth_0123456789abcdef',
  pairedAt: DateTime.utc(2026, 10, 5),
);

final PairedDevice _edge = _phone('phone_0123456789abc', 'Motorola Edge');
final PairedDevice _pixel = _phone('phone_abcdef0123456', 'Pixel 9');

/// Stands in for the real controller, which would start a server.
class _FakeLaptopPairing extends LaptopPairingController {
  @override
  Future<LaptopPairingState> build() async => LaptopPairedWithPhone(_pixel);

  @override
  void showNewCode() {
    state = AsyncData(
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
  }

  @override
  void stopPairing() => state = AsyncData(LaptopPairedWithPhone(_pixel));
}

class _TwoPairedDevices extends PairedDevicesNotifier {
  @override
  Future<List<PairedDevice>> build() async => [_edge, _pixel];
}

class _OnlyEdgeConnected extends ConnectedPhones {
  @override
  Set<String> build() => {_edge.deviceId};
}

class _NoIncoming extends IncomingTransfersController {
  @override
  List<IncomingTransferView> build() => const [];
}

Future<ProviderContainer> _openDevices(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1280, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: [
      laptopPairingProvider.overrideWith(_FakeLaptopPairing.new),
      pairedDevicesProvider.overrideWith(_TwoPairedDevices.new),
      connectedPhonesProvider.overrideWith(_OnlyEdgeConnected.new),
      incomingTransfersProvider.overrideWith(_NoIncoming.new),
    ],
  );
  addTearDown(container.dispose);
  final router = GoRouter(
    initialLocation: AppRoutes.laptopHome,
    routes: [
      GoRoute(
        path: AppRoutes.laptopHome,
        builder: (context, state) => const LaptopHomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.laptopPairing,
        builder: (context, state) => const LaptopPairingScreen(),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pump(const Duration(milliseconds: 400));
  await tester.tap(find.text('Devices'));
  await tester.pump(const Duration(milliseconds: 400));
  return container;
}

void main() {
  testWidgets('Devices counts and labels who is connected', (tester) async {
    await _openDevices(tester);

    expect(find.byType(LaptopDevicesView), findsOneWidget);
    expect(find.text('1 of 2 paired devices connected.'), findsOneWidget);
    expect(find.text('Motorola Edge'), findsOneWidget);
    expect(find.text('Pixel 9'), findsOneWidget);
    expect(find.text('Connected'), findsOneWidget);
    // The sidebar follows the phone in use, which is the offline one.
    expect(find.text('Offline'), findsNWidgets(2));
    expect(find.byType(PrettyQrView), findsNothing);
  });

  testWidgets('Add device shows a fresh code, and closing takes it down', (
    tester,
  ) async {
    final container = await _openDevices(tester);

    await tester.tap(find.text('Add device'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(PrettyQrView), findsOneWidget);
    expect(find.text('482 913'), findsOneWidget);

    await tester.tap(find.byTooltip('Back to Home'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(PrettyQrView), findsNothing);
    // A code must not stay redeemable once its QR is hidden.
    expect(
      container.read(laptopPairingProvider).value,
      isA<LaptopPairedWithPhone>(),
    );
  });

  testWidgets('removing a device asks first and keeps it on "Keep"', (
    tester,
  ) async {
    await _openDevices(tester);

    await tester.tap(find.text('Remove').first);
    await tester.pumpAndSettle();
    expect(find.text('Remove Pixel 9?'), findsOneWidget);

    await tester.tap(find.text('Keep'));
    await tester.pumpAndSettle();
    expect(find.text('Pixel 9'), findsOneWidget);
  });
}
