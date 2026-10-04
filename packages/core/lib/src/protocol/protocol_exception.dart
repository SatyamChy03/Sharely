/// Thrown when an incoming message breaks the protocol.
///
/// The [reason] never echoes the raw input, so it is safe to log.
class ProtocolException implements Exception {
  const new(this.reason);

  final String reason;

  @override
  String toString() => 'ProtocolException: $reason';
}
