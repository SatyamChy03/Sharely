import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sharely_core/sharely_core.dart';
import 'package:test/test.dart';

late Directory _folder;

File get _historyFile => File(p.join(_folder.path, 'nested', 'history.json'));

TransferHistoryEntry _entry(String name, {String? savedPath}) {
  return TransferHistoryEntry(
    name: name,
    sizeBytes: 2048,
    direction: savedPath == null
        ? TransferHistoryDirection.sent
        : TransferHistoryDirection.received,
    finishedAt: DateTime.utc(2026, 10, 7, 9, 30),
    savedPath: savedPath,
  );
}

Future<void> _writeRaw(Object? json) async {
  await _historyFile.parent.create(recursive: true);
  await _historyFile.writeAsString(jsonEncode(json));
}

Map<String, Object?> _rawEntry([Map<String, Object?> changes = const {}]) => {
  'name': 'photo.png',
  'size': 10,
  'direction': 'received',
  'finishedAt': 1791365400000,
  ...changes,
};

void main() {
  setUp(() async {
    _folder = await Directory.systemTemp.createTemp('sharely_history_');
  });
  tearDown(() => _folder.delete(recursive: true));

  test('nothing saved yet reads as an empty history', () async {
    expect(await TransferHistoryStore(_historyFile).load(), isEmpty);
  });

  test('a saved history comes back unchanged after a restart', () async {
    final savedPath = p.join(_folder.path, 'Downloads', 'photo.png');
    await TransferHistoryStore(_historyFile)
        .save([_entry('photo.png', savedPath: savedPath), _entry('notes.pdf')]);

    final loaded = await TransferHistoryStore(_historyFile).load();

    expect(loaded.map((entry) => entry.name), ['photo.png', 'notes.pdf']);
    expect(loaded.first.savedPath, savedPath);
    expect(loaded.first.direction, TransferHistoryDirection.received);
    expect(loaded.first.sizeBytes, 2048);
    expect(loaded.first.finishedAt, DateTime.utc(2026, 10, 7, 9, 30));
    expect(loaded.last.savedPath, isNull);
  });

  test('only the newest entries are kept past the limit', () async {
    final store = TransferHistoryStore(_historyFile);
    await store.save([
      for (var index = 0; index < maxHistoryEntries + 5; index++)
        _entry('file_$index.txt'),
    ]);

    final loaded = await store.load();

    expect(loaded, hasLength(maxHistoryEntries));
    expect(loaded.first.name, 'file_0.txt');
  });

  test('clearing removes the file, and clearing twice is harmless', () async {
    final store = TransferHistoryStore(_historyFile);
    await store.save([_entry('photo.png')]);

    await store.clear();
    await store.clear();

    expect(_historyFile.existsSync(), isFalse);
    expect(await store.load(), isEmpty);
  });

  test('saving leaves no draft file behind', () async {
    await TransferHistoryStore(_historyFile).save([_entry('photo.png')]);

    expect(File('${_historyFile.path}.tmp').existsSync(), isFalse);
  });

  group('a tampered or damaged file is rejected', () {
    final badFiles = <String, Object?>{
      'not an object': ['entries'],
      'unknown version': {'version': 2, 'entries': <Object>[]},
      'unknown top-level field': {
        'version': 1,
        'entries': <Object>[],
        'extra': true,
      },
      'unknown entry field': {
        'version': 1,
        'entries': [
          _rawEntry({'command': 'rm'}),
        ],
      },
      'negative size': {
        'version': 1,
        'entries': [
          _rawEntry({'size': -1}),
        ],
      },
      'unknown direction': {
        'version': 1,
        'entries': [
          _rawEntry({'direction': 'sideways'}),
        ],
      },
      'relative saved path': {
        'version': 1,
        'entries': [
          _rawEntry({'savedPath': '../../etc/passwd'}),
        ],
      },
      'control characters in the name': {
        'version': 1,
        'entries': [
          _rawEntry({'name': 'a\nb'}),
        ],
      },
      'too many entries': {
        'version': 1,
        'entries': [
          for (var index = 0; index <= maxHistoryEntries; index++) _rawEntry(),
        ],
      },
    };
    for (final MapEntry(key: reason, value: json) in badFiles.entries) {
      test(reason, () async {
        await _writeRaw(json);

        expect(
          TransferHistoryStore(_historyFile).load(),
          throwsA(isA<ProtocolException>()),
        );
      });
    }

    test('text that is not JSON', () async {
      await _historyFile.parent.create(recursive: true);
      await _historyFile.writeAsString('{"version": 1, "entr');

      expect(
        TransferHistoryStore(_historyFile).load(),
        throwsA(isA<ProtocolException>()),
      );
    });
  });
}
