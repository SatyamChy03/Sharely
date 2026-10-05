import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sharely/features/pairing/state/camera_permission_gateway.dart';

/// Where the camera permission stands from the scan screen's point of view.
enum CameraAccess {
  notRequested,
  denied,

  /// Denied with "don't ask again": only system settings can grant it now.
  blocked,
  granted,
}

final cameraAccessProvider =
    AsyncNotifierProvider<CameraAccessController, CameraAccess>(
      CameraAccessController.new,
    );

/// Asks for the camera before the scanner exists, so it never starts blind.
class CameraAccessController extends AsyncNotifier<CameraAccess> {
  CameraPermissionGateway get _gateway =>
      ref.read(cameraPermissionGatewayProvider);

  @override
  Future<CameraAccess> build() async {
    final status = await _gateway.currentStatus();
    // Android reports "never asked" and "denied once" alike before a request.
    return _accessFor(status, ifDenied: CameraAccess.notRequested);
  }

  Future<void> requestAccess() async {
    final status = await _gateway.requestAccess();
    if (!ref.mounted) return;
    state = AsyncData(_accessFor(status, ifDenied: CameraAccess.denied));
  }

  Future<void> openSystemSettings() => _gateway.openSystemSettings();

  /// Picks up a grant made in system settings while the app was away.
  Future<void> recheckAfterResume() async {
    if (state.value == CameraAccess.granted) return;
    final status = await _gateway.currentStatus();
    if (!ref.mounted || !status.isGranted) return;
    state = const AsyncData(CameraAccess.granted);
  }

  CameraAccess _accessFor(
    PermissionStatus status, {
    required CameraAccess ifDenied,
  }) {
    if (status.isGranted || status.isLimited) return CameraAccess.granted;
    if (status.isPermanentlyDenied || status.isRestricted) {
      return CameraAccess.blocked;
    }
    return ifDenied;
  }
}
