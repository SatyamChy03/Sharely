import 'package:sharely_core/src/transfer/transfer_exception.dart';

/// What the sending UI shows, in order, for one transfer.
sealed class OutgoingTransferUpdate {
  const new();
}

/// Checksumming files before the offer goes out.
final class OutgoingTransferPreparing extends OutgoingTransferUpdate {
  const new({required this.filesReady, required this.fileCount});

  final int filesReady;
  final int fileCount;
}

final class OutgoingTransferAwaitingAcceptance extends OutgoingTransferUpdate {
  const new();
}

final class OutgoingTransferSending extends OutgoingTransferUpdate {
  const new({required this.bytesSent, required this.totalBytes});

  final int bytesSent;
  final int totalBytes;
}

final class OutgoingTransferCompleted extends OutgoingTransferUpdate {
  const new();
}

final class OutgoingTransferFailed extends OutgoingTransferUpdate {
  const new(this.reason);

  final TransferFailure reason;
}
