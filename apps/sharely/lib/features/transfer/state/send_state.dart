import 'package:sharely_core/sharely_core.dart';

/// The phone's current send, as the sending screen shows it.
sealed class SendState {
  const new();
}

final class SendIdle extends SendState {
  const new();
}

/// The fields every active or finished send shares.
sealed class SendWithFiles extends SendState {
  const new({required this.fileCount, required this.totalBytes});

  final int fileCount;
  final int totalBytes;
}

final class SendPreparing extends SendWithFiles {
  const new({required super.fileCount, required super.totalBytes});
}

final class SendAwaitingAcceptance extends SendWithFiles {
  const new({required super.fileCount, required super.totalBytes});
}

final class SendInProgress extends SendWithFiles {
  const new({
    required super.fileCount,
    required super.totalBytes,
    required this.bytesSent,
    required this.bytesPerSecond,
  });

  final int bytesSent;
  final double bytesPerSecond;

  double get fraction => totalBytes == 0 ? 1 : bytesSent / totalBytes;

  Duration? get timeLeft {
    if (bytesPerSecond <= 0) return null;
    final secondsLeft = (totalBytes - bytesSent) / bytesPerSecond;
    return Duration(seconds: secondsLeft.ceil());
  }
}

final class SendSucceeded extends SendWithFiles {
  const new({required super.fileCount, required super.totalBytes});
}

final class SendFailed extends SendWithFiles {
  const new({
    required super.fileCount,
    required super.totalBytes,
    required this.reason,
  });

  final TransferFailure reason;
}
