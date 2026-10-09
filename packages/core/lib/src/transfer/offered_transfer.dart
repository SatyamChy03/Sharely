import 'dart:async';

import 'package:sharely_core/src/transfer/outgoing_file.dart';

/// Sender-side bookkeeping for one offer. Internal to the sender.
class OfferedTransfer {
  new({
    required this.deviceId,
    required this.files,
    required this.decisionTimer,
  });

  final String deviceId;
  final List<OutgoingFile> files;
  final Timer decisionTimer;

  bool isAccepted = false;
  bool isEnded = false;
  int bytesSent = 0;

  /// The newest download of each file in flight. A resumed download takes
  /// over its file, which tells the stuck one it replaced to stop.
  final Map<int, Object> currentServes = {};
  final Stopwatch sinceLastProgressReport = Stopwatch()..start();

  /// Runs while nothing is being downloaded; ends the transfer when it fires.
  Timer? stallTimer;

  int get totalBytes => files.fold(0, (sum, file) => sum + file.sizeBytes);

  int bytesBefore(int fileIndex) =>
      files.take(fileIndex).fold(0, (sum, file) => sum + file.sizeBytes);

  bool isServing(int fileIndex, Object serve) =>
      !isEnded && identical(currentServes[fileIndex], serve);
}
