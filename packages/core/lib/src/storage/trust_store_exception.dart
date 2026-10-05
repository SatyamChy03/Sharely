/// The stored trust data could not be read back safely.
class TrustStoreException implements Exception {
  const new(this.message);

  final String message;

  @override
  String toString() => 'TrustStoreException: $message';
}
