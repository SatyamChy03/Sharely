import 'dart:io';

import 'package:flutter/foundation.dart';

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

  final String name;
  final int sizeBytes;
  final TransferDirection direction;
  final DateTime finishedAt;

  /// Where a received file landed, for "Show in folder".
  final File? savedFile;
}
