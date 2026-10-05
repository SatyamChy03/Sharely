enum TransferFailure {
  /// The receiver declined the offer.
  rejected,

  /// Either side cancelled.
  cancelled,

  /// The other device could not be reached, or the connection dropped.
  unreachable,

  /// Nobody answered the offer in time.
  timedOut,

  /// The bytes received did not match the declared size or checksum.
  corrupted,

  /// The other side broke the protocol or refused the request.
  refused,

  /// A file to send was moved, deleted or unreadable.
  unreadableFile,
}

class TransferException implements Exception {
  const new(this.failure);

  final TransferFailure failure;

  @override
  String toString() => 'TransferException: ${failure.name}';
}
