import 'dart:io';

import 'package:sharely_core/src/history/transfer_history_entry.dart';
import 'package:sharely_core/src/history/transfer_history_records.dart';
import 'package:sharely_core/src/protocol/protocol_exception.dart';

// 300 entries with the longest allowed names and paths stay under this.
const int _maxHistoryFileBytes = 4 * 1024 * 1024;

/// Keeps the transfer history in one file in the app's private folder.
///
/// It holds file names and sizes only, never file contents.
class TransferHistoryStore {
  const new(this._file);

  final File _file;

  /// The saved history, newest first; empty when nothing was saved yet.
  ///
  /// Throws a [ProtocolException] when the file fails validation, and a
  /// [FileSystemException] when it cannot be read.
  Future<List<TransferHistoryEntry>> load() async {
    if (!_file.existsSync()) return const [];
    if (await _file.length() > _maxHistoryFileBytes) {
      throw const ProtocolException('History file is too large');
    }
    final String stored;
    try {
      stored = await _file.readAsString();
    } on FormatException {
      throw const ProtocolException('History file is not UTF-8');
    }
    return decodeTransferHistory(stored);
  }

  /// Replaces the saved history with [entries], newest first.
  Future<void> save(List<TransferHistoryEntry> entries) async {
    await _file.parent.create(recursive: true);
    // Written aside then renamed, so a crash never leaves half a file.
    final draft = File('${_file.path}.tmp');
    await draft.writeAsString(encodeTransferHistory(entries), flush: true);
    await draft.rename(_file.path);
  }

  Future<void> clear() async {
    if (_file.existsSync()) await _file.delete();
  }
}
