/// Names the calling device; the bearer token then has to match its pairing.
const sharelyDeviceHeader = 'x-sharely-device';

const _bearerPrefix = 'Bearer ';

/// Headers that prove this device is paired with the one it calls.
Map<String, String> buildAuthHeaders({
  required String localDeviceId,
  required String authToken,
}) => {
  'authorization': '$_bearerPrefix$authToken',
  sharelyDeviceHeader: localDeviceId,
};

/// The token from an `Authorization: Bearer` header, or null if malformed.
String? readBearerToken(String? authorization) {
  if (authorization == null || !authorization.startsWith(_bearerPrefix)) {
    return null;
  }
  return authorization.substring(_bearerPrefix.length);
}
