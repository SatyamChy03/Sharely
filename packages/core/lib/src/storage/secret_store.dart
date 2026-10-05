/// Key-value storage for secrets, backed by the platform's secure storage.
abstract interface class SecretStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}
