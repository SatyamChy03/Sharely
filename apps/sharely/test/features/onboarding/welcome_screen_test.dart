import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sharely/app/router.dart';
import 'package:sharely/app/sharely_app.dart';
import 'package:sharely/app/storage/trust_store_provider.dart';
import 'package:sharely/features/home/home_screen.dart';
import 'package:sharely/features/pairing/scan_screen.dart';
import 'package:sharely/features/pairing/state/camera_permission_gateway.dart';
import 'package:sharely/features/pairing/state/paired_devices.dart';
import 'package:sharely/features/pairing/widgets/qr_scanner.dart';
import 'package:sharely_core/sharely_core.dart';

import '../pairing/fake_camera_permission_gateway.dart';

void main() {
  Future<void> pumpSharelyApp(
    WidgetTester tester, {
    List<PairedDevice> pairedDevices = const [],
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final trustStore = TrustStore(MemorySecretStore());
    await trustStore.savePairedDevices(pairedDevices);
    final container = ProviderContainer(
      overrides: [
        trustStoreProvider.overrideWithValue(trustStore),
        isDesktopRoleProvider.overrideWithValue(false),
        cameraPermissionGatewayProvider.overrideWithValue(
          FakeCameraPermissionGateway(),
        ),
        // Tests have no camera; stand in an empty preview.
        qrScannerBuilderProvider.overrideWithValue(
          (context, onCode) => const SizedBox.expand(),
        ),
      ],
    );
    addTearDown(container.dispose);
    // Mirrors main(): trust is loaded before the first frame.
    await tester.runAsync(() => container.read(pairedDevicesProvider.future));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const SharelyApp(),
      ),
    );
    // The orbit animation loops forever, so pump a fixed time, not settle.
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('welcome screen shows the promise and how files travel', (
    tester,
  ) async {
    await pumpSharelyApp(tester);

    expect(find.text('Get started'), findsOneWidget);
    expect(find.text('Files go directly between your devices'), findsOneWidget);
  });

  testWidgets('a phone that is already paired opens on Home', (tester) async {
    await pumpSharelyApp(
      tester,
      pairedDevices: [
        PairedDevice(
          deviceId: 'laptop_0123456789ab',
          deviceName: 'Laptop',
          platform: DevicePlatform.windows,
          authToken: 'auth_0123456789abcdef',
          pairedAt: DateTime.utc(2026, 10, 5),
        ),
      ],
    );

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Get started'), findsNothing);
  });

  testWidgets('get started opens the scan step', (tester) async {
    await pumpSharelyApp(tester);

    await tester.tap(find.text('Get started'));
    await tester.pump(const Duration(seconds: 1));
    // flutter_animate starts with a zero-length timer; flush it.
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.byType(ScanScreen), findsOneWidget);
  });
}
