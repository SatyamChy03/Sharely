import 'dart:async';
import 'dart:io';

import 'package:sharely_core/src/pairing/paired_device.dart';
import 'package:sharely_core/src/protocol/protocol_message.dart';
import 'package:sharely_core/src/transfer/incoming_file_writer.dart';

enum IncomingTransferStage { awaitingDecision, receiving }

/// One upload request in flight: how to break it off, and when it is over.
typedef ActiveUpload = ({Completer<void> interrupt, Completer<void> settled});

/// Receiver-side bookkeeping for one offer. Internal to the receiver.
class IncomingTransfer {
  new({required this.sender, required this.offer});

  final PairedDevice sender;
  final OfferMessage offer;

  IncomingTransferStage stage = IncomingTransferStage.awaitingDecision;
  bool isEnded = false;
  int bytesReceived = 0;

  /// Files started but not finished, kept so a broken upload can resume.
  final Map<int, PartialIncomingFile> partials = {};
  final Map<int, ActiveUpload> activeUploads = {};
  final Map<int, File> savedFilesByIndex = {};
  final Stopwatch sinceLastProgressReport = Stopwatch()..start();

  /// Runs while nothing is arriving; ends the transfer when it fires.
  Timer? stallTimer;

  bool get hasAllFiles => savedFilesByIndex.length == offer.files.length;

  /// In offer order, whatever order the uploads finished in.
  List<File> get savedFiles {
    final byIndex = savedFilesByIndex.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return [for (final saved in byIndex) saved.value];
  }

  bool isFrom(PairedDevice device) => sender.deviceId == device.deviceId;

  /// Breaks off the upload of [fileIndex], if any, and waits until it has
  /// let go of the file.
  Future<void> settleUpload(int fileIndex) async {
    final upload = activeUploads[fileIndex];
    if (upload == null) return;
    if (!upload.interrupt.isCompleted) upload.interrupt.complete();
    await upload.settled.future;
  }

  /// Deletes unfinished files; ones still being written delete themselves
  /// once their upload has been broken off.
  void releaseUnfinishedFiles() {
    for (final upload in activeUploads.values) {
      if (!upload.interrupt.isCompleted) upload.interrupt.complete();
    }
    final idle = partials.keys
        .where((index) => !activeUploads.containsKey(index))
        .toList();
    for (final index in idle) {
      unawaited(partials.remove(index)?.discard());
    }
  }
}
