import 'package:permission_handler/permission_handler.dart';
import 'package:sharely/features/pairing/state/camera_permission_gateway.dart';

/// Answers permission checks from fixed statuses and records what was asked.
class FakeCameraPermissionGateway extends CameraPermissionGateway {
  new({
    this.currentStatusValue = PermissionStatus.denied,
    this.requestResult = PermissionStatus.granted,
  });

  PermissionStatus currentStatusValue;
  PermissionStatus requestResult;
  int requestCount = 0;
  int settingsOpenCount = 0;

  @override
  Future<PermissionStatus> currentStatus() async => currentStatusValue;

  @override
  Future<PermissionStatus> requestAccess() async {
    requestCount++;
    currentStatusValue = requestResult;
    return requestResult;
  }

  @override
  Future<bool> openSystemSettings() async {
    settingsOpenCount++;
    return true;
  }
}
