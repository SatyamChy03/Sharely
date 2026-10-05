import 'package:sharely_core/src/pairing/paired_device.dart';
import 'package:sharely_core/src/protocol/protocol_ids.dart';
import 'package:sharely_core/src/security/constant_time.dart';
import 'package:sharely_core/src/transfer/auth_headers.dart';
import 'package:shelf/shelf.dart';

typedef PairedDeviceLookup = PairedDevice? Function(String deviceId);

const _deviceContextKey = 'sharely.pairedDevice';

/// Admits only paired devices; anyone else gets a bare 401 and no data.
Middleware requirePairedDevice(PairedDeviceLookup findPairedDevice) {
  return (inner) => (request) {
    final device = authenticateRequest(request.headers, findPairedDevice);
    if (device == null) return Response.unauthorized(null);
    return inner(request.change(context: {_deviceContextKey: device}));
  };
}

/// The device [requirePairedDevice] admitted this request for.
PairedDevice authenticatedDevice(Request request) {
  final device = request.context[_deviceContextKey];
  if (device is! PairedDevice) {
    throw StateError('Route is missing requirePairedDevice');
  }
  return device;
}

PairedDevice? authenticateRequest(
  Map<String, String> headers,
  PairedDeviceLookup findPairedDevice,
) {
  final deviceId = headers[sharelyDeviceHeader];
  final token = readBearerToken(headers['authorization']);
  if (deviceId == null || token == null || !isValidProtocolId(deviceId)) {
    return null;
  }
  final device = findPairedDevice(deviceId);
  if (device == null || !constantTimeEquals(token, device.authToken)) {
    return null;
  }
  return device;
}
