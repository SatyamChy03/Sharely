import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

/// Generates an unguessable URL-safe id from the OS secure random source.
///
/// 16 bytes gives 128 bits of entropy, encoded as 22 characters.
String generateSecureId({int byteLength = 16}) {
  if (byteLength < 16) {
    throw ArgumentError.value(byteLength, 'byteLength', 'must be at least 16');
  }
  final random = Random.secure();
  final bytes = Uint8List(byteLength);
  for (var index = 0; index < byteLength; index++) {
    bytes[index] = random.nextInt(256);
  }
  return base64Url.encode(bytes).replaceAll('=', '');
}
