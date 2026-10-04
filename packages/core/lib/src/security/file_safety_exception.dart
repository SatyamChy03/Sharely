/// Thrown when an incoming file cannot be saved safely.
class FileSafetyException implements Exception {
  const new(this.reason);

  final String reason;

  @override
  String toString() => 'FileSafetyException: $reason';
}
