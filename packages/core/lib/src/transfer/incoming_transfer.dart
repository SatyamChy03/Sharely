import 'dart:io';

import 'package:sharely_core/src/pairing/paired_device.dart';
import 'package:sharely_core/src/protocol/protocol_message.dart';

enum IncomingTransferStage { awaitingDecision, receiving }

/// Receiver-side bookkeeping for one offer. Internal to the receiver.
class IncomingTransfer {
  new({required this.sender, required this.offer});

  final PairedDevice sender;
  final OfferMessage offer;

  IncomingTransferStage stage = IncomingTransferStage.awaitingDecision;
  bool isEnded = false;
  int bytesReceived = 0;
  final Set<int> startedFileIndexes = {};
  final List<File> savedFiles = [];
  final Stopwatch sinceLastProgressReport = Stopwatch()..start();

  bool get hasAllFiles => savedFiles.length == offer.files.length;

  bool isFrom(PairedDevice device) => sender.deviceId == device.deviceId;
}
