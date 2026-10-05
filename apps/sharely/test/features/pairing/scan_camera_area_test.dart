import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sharely/features/pairing/state/camera_permission_gateway.dart';
import 'package:sharely/features/pairing/widgets/qr_scanner.dart';
import 'package:sharely/features/pairing/widgets/scan_camera_area.dart';

import 'fake_camera_permission_gateway.dart';

const _cameraPreviewKey = Key('camera-preview');

Future<void> _pumpCameraArea(
  WidgetTester tester,
  FakeCameraPermissionGateway gateway,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        cameraPermissionGatewayProvider.overrideWithValue(gateway),
        qrScannerBuilderProvider.overrideWithValue(
          (context, onCode) => const SizedBox.expand(key: _cameraPreviewKey),
        ),
      ],
      child: const MaterialApp(home: Scaffold(body: ScanCameraArea())),
    ),
  );
  await tester.pump();
  // flutter_animate starts with a zero-length timer; flush it.
  await tester.pump(const Duration(milliseconds: 1));
}

void main() {
  testWidgets('asks before opening the camera, then shows the scanner', (
    tester,
  ) async {
    final gateway = FakeCameraPermissionGateway();
    await _pumpCameraArea(tester, gateway);

    expect(find.byKey(_cameraPreviewKey), findsNothing);
    await tester.tap(find.text('Allow camera'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    expect(gateway.requestCount, 1);
    expect(find.byKey(_cameraPreviewKey), findsOneWidget);
  });

  testWidgets('a denial offers to ask again', (tester) async {
    final gateway = FakeCameraPermissionGateway(
      requestResult: PermissionStatus.denied,
    );
    await _pumpCameraArea(tester, gateway);

    await tester.tap(find.text('Allow camera'));
    await tester.pump();

    expect(find.text('Camera access is off'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('a blocked camera sends the user to system settings', (
    tester,
  ) async {
    final gateway = FakeCameraPermissionGateway(
      currentStatusValue: PermissionStatus.permanentlyDenied,
    );
    await _pumpCameraArea(tester, gateway);

    await tester.tap(find.text('Open settings'));
    await tester.pump();

    expect(gateway.settingsOpenCount, 1);
    expect(gateway.requestCount, 0);
  });
}
