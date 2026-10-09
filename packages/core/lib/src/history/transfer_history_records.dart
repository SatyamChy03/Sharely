import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sharely_core/src/history/transfer_history_entry.dart';
import 'package:sharely_core/src/protocol/json_fields.dart';
import 'package:sharely_core/src/protocol/protocol_exception.dart';
import 'package:sharely_core/src/protocol/protocol_limits.dart';

/// Older entries make room for newer ones past this many.
const int maxHistoryEntries = 300;

const _recordsVersion = 1;
const _maxSavedPathChars = 4096;

// Year 2100: anything later means the record was tampered with or corrupted.
const _maxFinishedAtMillis = 4102444800000;

/// Serialises [entries], newest first, keeping at most [maxHistoryEntries].
String encodeTransferHistory(List<TransferHistoryEntry> entries) {
  return jsonEncode({
    'version': _recordsVersion,
    'entries': [
      for (final entry in entries.take(maxHistoryEntries)) _encodeEntry(entry),
    ],
  });
}

/// Reads a stored history with the same strictness as network input.
List<TransferHistoryEntry> decodeTransferHistory(String stored) {
  final fields = JsonFields(decodeJsonObject(stored))
    ..requireOnlyKeys(const {'version', 'entries'});
  if (fields.integer('version', min: 1, max: 1000) != _recordsVersion) {
    throw const ProtocolException('Unsupported history version');
  }
  final records = fields.objectList(
    'entries',
    minLength: 0,
    maxLength: maxHistoryEntries,
  );
  return List.unmodifiable(records.map(_decodeEntry));
}

Map<String, Object?> _encodeEntry(TransferHistoryEntry entry) => {
  'name': entry.name,
  'size': entry.sizeBytes,
  'direction': entry.direction.name,
  'finishedAt': entry.finishedAt.toUtc().millisecondsSinceEpoch,
  'savedPath': ?entry.savedPath,
};

TransferHistoryEntry _decodeEntry(JsonFields fields) {
  fields.requireOnlyKeys(const {
    'name',
    'size',
    'direction',
    'finishedAt',
    'savedPath',
  });
  final directionName = fields.string('direction', maxLength: 16);
  final direction = TransferHistoryDirection.values
      .where((value) => value.name == directionName)
      .firstOrNull;
  if (direction == null) {
    throw const ProtocolException('Unknown history direction');
  }
  final savedPath = fields.has('savedPath')
      ? fields.string('savedPath', maxLength: _maxSavedPathChars)
      : null;
  if (savedPath != null && !p.isAbsolute(savedPath)) {
    throw const ProtocolException('Saved path must be absolute');
  }
  return TransferHistoryEntry(
    name: fields.string('name', maxLength: ProtocolLimits.maxFileNameChars),
    sizeBytes: fields.integer(
      'size',
      min: 0,
      max: ProtocolLimits.maxFileSizeBytes,
    ),
    direction: direction,
    finishedAt: DateTime.fromMillisecondsSinceEpoch(
      fields.integer('finishedAt', min: 0, max: _maxFinishedAtMillis),
      isUtc: true,
    ),
    savedPath: savedPath,
  );
}
