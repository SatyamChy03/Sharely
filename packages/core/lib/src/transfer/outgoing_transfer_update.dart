import 'package:sharely_core/src/transfer/transfer_exception.dart';

/// What the sending UI shows, in order, for one transfer.
sealed class OutgoingTransferUpdate {
  const new();
}

final class OutgoingTransferAwaitingAcceptance extends OutgoingTransferUpdate {
  const new();
}

final class OutgoingTransferSending extends OutgoingTransferUpdate {
  const new({required this.bytesSent, required this.totalBytes});

  final int bytesSent;
  final int totalBytes;
}

/// The connection dropped mid-transfer; it resumes by itself if the other
/// device comes back in time. The next sending update means it has.
final class OutgoingTransferReconnecting extends OutgoingTransferUpdate {
  const new();
}

final class OutgoingTransferCompleted extends OutgoingTransferUpdate {
  const new();
}

final class OutgoingTransferFailed extends OutgoingTransferUpdate {
  const new(this.reason);

  final TransferFailure reason;
}
