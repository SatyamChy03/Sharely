import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

/// Overridden in tests, which have no permission plugin.
final cameraPermissionGatewayProvider = Provider<CameraPermissionGateway>(
  (ref) => const CameraPermissionGateway(),
);

/// Thin wrapper over the OS camera permission.
class CameraPermissionGateway {
  const new();

  Future<PermissionStatus> currentStatus() => Permission.camera.status;

  Future<PermissionStatus> requestAccess() => Permission.camera.request();

  Future<bool> openSystemSettings() => openAppSettings();
}
