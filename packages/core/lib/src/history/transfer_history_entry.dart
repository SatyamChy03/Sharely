import 'package:meta/meta.dart';

enum TransferHistoryDirection { sent, received }

/// One finished file, as remembered in this device's transfer history.
@immutable
final class TransferHistoryEntry {
  const new({
    required this.name,
    required this.sizeBytes,
    required this.direction,
    required this.finishedAt,
    this.savedPath,
  });

  final String name;
  final int sizeBytes;
  final TransferHistoryDirection direction;
  final DateTime finishedAt;

  /// Where a received file was saved; null for files this device sent.
  final String? savedPath;
}
