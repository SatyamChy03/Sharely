import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sharely_core/sharely_core.dart';

/// Keystore on Android, Credential Manager on Windows, libsecret on Linux.
class PlatformSecretStore implements SecretStore {
  const new();

  static const _storage = FlutterSecureStorage();

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}
