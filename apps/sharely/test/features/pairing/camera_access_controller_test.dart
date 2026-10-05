import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sharely/features/pairing/state/camera_access_controller.dart';
import 'package:sharely/features/pairing/state/camera_permission_gateway.dart';

import 'fake_camera_permission_gateway.dart';

ProviderContainer _containerWith(FakeCameraPermissionGateway gateway) {
  final container = ProviderContainer(
    overrides: [cameraPermissionGatewayProvider.overrideWithValue(gateway)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  final startingAccess = {
    PermissionStatus.denied: CameraAccess.notRequested,
    PermissionStatus.granted: CameraAccess.granted,
    PermissionStatus.permanentlyDenied: CameraAccess.blocked,
    PermissionStatus.restricted: CameraAccess.blocked,
  };
  for (final MapEntry(key: status, value: access) in startingAccess.entries) {
    test('starts as $access when the OS reports $status', () async {
      final container = _containerWith(
        FakeCameraPermissionGateway(currentStatusValue: status),
      );
      expect(await container.read(cameraAccessProvider.future), access);
    });
  }

  final afterRequest = {
    PermissionStatus.granted: CameraAccess.granted,
    PermissionStatus.denied: CameraAccess.denied,
    PermissionStatus.permanentlyDenied: CameraAccess.blocked,
  };
  for (final MapEntry(key: status, value: access) in afterRequest.entries) {
    test('a request answered with $status leads to $access', () async {
      final gateway = FakeCameraPermissionGateway(requestResult: status);
      final container = _containerWith(gateway);
      await container.read(cameraAccessProvider.future);

      await container.read(cameraAccessProvider.notifier).requestAccess();

      expect(gateway.requestCount, 1);
      expect(container.read(cameraAccessProvider).value, access);
    });
  }

  test('a grant made in system settings is picked up on resume', () async {
    final gateway = FakeCameraPermissionGateway(
      currentStatusValue: PermissionStatus.permanentlyDenied,
    );
    final container = _containerWith(gateway);
    await container.read(cameraAccessProvider.future);

    gateway.currentStatusValue = PermissionStatus.granted;
    await container.read(cameraAccessProvider.notifier).recheckAfterResume();

    expect(container.read(cameraAccessProvider).value, CameraAccess.granted);
  });
}
