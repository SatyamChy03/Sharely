enum PairingFailure {
  /// The laptop could not be reached (different Wi-Fi, firewall, asleep).
  unreachable,

  /// The code or QR was wrong, already used, or expired.
  rejected,

  /// The other side answered with something that breaks the protocol.
  invalidResponse,
}

class PairingException implements Exception {
  const new(this.failure);

  final PairingFailure failure;

  @override
  String toString() => 'PairingException: ${failure.name}';
}
