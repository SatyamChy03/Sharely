import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:sharely_core/sharely_core.dart';

enum TransferDirection { sent, received }

/// One finished file in the Recent and History lists.
@immutable
final class RecentTransfer {
  const new({
    required this.name,
    required this.sizeBytes,
    required this.direction,
    required this.finishedAt,
    this.savedFile,
  });

  factory fromHistory(TransferHistoryEntry entry) {
    final savedPath = entry.savedPath;
    return RecentTransfer(
      name: entry.name,
      sizeBytes: entry.sizeBytes,
      direction: switch (entry.direction) {
        TransferHistoryDirection.sent => TransferDirection.sent,
        TransferHistoryDirection.received => TransferDirection.received,
      },
      finishedAt: entry.finishedAt.toLocal(),
      savedFile: savedPath == null ? null : File(savedPath),
    );
  }

  final String name;
  final int sizeBytes;
  final TransferDirection direction;
  final DateTime finishedAt;

  /// Where a received file landed, for "Show in folder".
  final File? savedFile;

  TransferHistoryEntry toHistory() {
    return TransferHistoryEntry(
      name: name,
      sizeBytes: sizeBytes,
      direction: switch (direction) {
        TransferDirection.sent => TransferHistoryDirection.sent,
        TransferDirection.received => TransferHistoryDirection.received,
      },
      finishedAt: finishedAt,
      savedPath: savedFile?.absolute.path,
    );
  }
}
