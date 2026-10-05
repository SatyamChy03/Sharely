import 'package:sharely_core/sharely_core.dart';

const _units = ['B', 'KB', 'MB', 'GB', 'TB'];

/// "4.2 MB", "820 KB", "12 B".
String formatByteCount(int bytes) {
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1000 && unit < _units.length - 1) {
    value /= 1000;
    unit++;
  }
  final digits = unit == 0 || value >= 100 ? 0 : 1;
  return '${value.toStringAsFixed(digits)} ${_units[unit]}';
}

String formatSpeed(double bytesPerSecond) =>
    '${formatByteCount(bytesPerSecond.round())}/s';

/// "12 s", "3 min", "2 h".
String formatDurationShort(Duration duration) {
  if (duration.inSeconds < 60) return '${duration.inSeconds} s';
  if (duration.inMinutes < 60) return '${duration.inMinutes} min';
  return '${duration.inHours} h';
}

/// "just now", "4 min ago", "2 h ago", "3 d ago".
String formatTimeAgo(DateTime moment, {DateTime? now}) {
  final elapsed = (now ?? DateTime.now()).difference(moment);
  if (elapsed.inMinutes < 1) return 'just now';
  if (elapsed.inHours < 1) return '${elapsed.inMinutes} min ago';
  if (elapsed.inDays < 1) return '${elapsed.inHours} h ago';
  return '${elapsed.inDays} d ago';
}

String formatFileCount(int count) => count == 1 ? '1 file' : '$count files';

/// What went wrong for the sender, with the one thing to try next.
String describeSendFailure(TransferFailure reason) => switch (reason) {
  TransferFailure.rejected =>
    'Your laptop declined. Ask whoever is at it to accept, then send again.',
  TransferFailure.cancelled => 'The transfer was cancelled.',
  TransferFailure.unreachable =>
    'Lost the connection to your laptop. Keep both on the same Wi-Fi and '
        'try again.',
  TransferFailure.timedOut =>
    'Nobody answered on your laptop. Accept the prompt there, then send '
        'again.',
  TransferFailure.corrupted => "A file didn't arrive intact. Send it again.",
  TransferFailure.refused =>
    "Your laptop couldn't save the files. Check it has free space, then "
        'try again.',
  TransferFailure.unreadableFile =>
    "Couldn't read one of the files. Pick it again and resend.",
};

/// What went wrong for the receiver, with the one thing to try next.
String describeReceiveFailure(TransferFailure reason, String senderName) =>
    switch (reason) {
      TransferFailure.cancelled => '$senderName cancelled the transfer.',
      TransferFailure.unreachable =>
        '$senderName disconnected. Ask it to send again on the same Wi-Fi.',
      TransferFailure.corrupted =>
        'A file arrived damaged and was discarded. Ask $senderName to send '
            'it again.',
      TransferFailure.refused =>
        "Couldn't save the files. Check there is free space in Downloads.",
      TransferFailure.rejected ||
      TransferFailure.timedOut ||
      TransferFailure.unreadableFile => 'The transfer stopped early.',
    };
