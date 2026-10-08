import 'package:sharely_core/sharely_core.dart';

/// The phone's current send, as the sending screen shows it.
sealed class SendState {
  const new();
}

final class SendIdle extends SendState {
  const new();
}

typedef SendFileInfo = ({String name, int sizeBytes});

/// The fields every active or finished send shares.
sealed class SendWithFiles extends SendState {
  const new({required this.files});

  final List<SendFileInfo> files;

  int get fileCount => files.length;

  int get totalBytes => files.fold(0, (sum, file) => sum + file.sizeBytes);
}

final class SendPreparing extends SendWithFiles {
  const new({required super.files});
}

final class SendAwaitingAcceptance extends SendWithFiles {
  const new({required super.files});
}

final class SendInProgress extends SendWithFiles {
  const new({
    required super.files,
    required this.bytesSent,
    required this.bytesPerSecond,
    this.isReconnecting = false,
  });

  final int bytesSent;
  final double bytesPerSecond;

  /// The connection dropped; the send continues by itself when it is back.
  final bool isReconnecting;

  double get fraction => totalBytes == 0 ? 1 : bytesSent / totalBytes;

  /// Files fully sent so far, assuming they go one after another in order.
  int get filesDone {
    var bytesBefore = 0;
    var done = 0;
    for (final file in files) {
      bytesBefore += file.sizeBytes;
      if (bytesBefore > bytesSent) break;
      done++;
    }
    return done;
  }

  Duration? get timeLeft {
    if (bytesPerSecond <= 0) return null;
    final secondsLeft = (totalBytes - bytesSent) / bytesPerSecond;
    return Duration(seconds: secondsLeft.ceil());
  }
}

final class SendSucceeded extends SendWithFiles {
  const new({required super.files});
}

final class SendFailed extends SendWithFiles {
  const new({required super.files, required this.reason});

  final TransferFailure reason;
}
