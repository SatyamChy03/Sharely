import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sharely/app/storage/history_storage.dart';
import 'package:sharely/features/transfer/state/recent_transfer.dart';
import 'package:sharely/features/transfer/state/recent_transfers.dart';
import 'package:sharely_core/sharely_core.dart';

late Directory _folder;

TransferHistoryStore get _store =>
    TransferHistoryStore(File('${_folder.path}/transfer_history.json'));

/// Starts the app's history the way `main` does: from what is on disk.
Future<ProviderContainer> _openApp() async {
  final container = ProviderContainer(
    overrides: [
      historyStoreProvider.overrideWithValue(_store),
      savedHistoryProvider.overrideWithValue(await _store.load()),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

RecentTransfer _received(String name) => RecentTransfer(
  name: name,
  sizeBytes: 1200,
  direction: TransferDirection.received,
  finishedAt: DateTime(2026, 10, 7, 9, 30),
  savedFile: File('${_folder.path}/Downloads/$name'),
);

void main() {
  setUp(() async {
    _folder = await Directory.systemTemp.createTemp('sharely_app_history_');
  });
  tearDown(() => _folder.delete(recursive: true));

  test('history is still there after the app restarts', () async {
    final firstRun = await _openApp();
    final history = firstRun.read(recentTransfersProvider.notifier)
      ..record([_received('photo.png')])
      ..record([_received('notes.pdf')]);
    await history.saved;

    final secondRun = await _openApp();
    final restored = secondRun.read(recentTransfersProvider);

    expect(restored.map((transfer) => transfer.name), [
      'notes.pdf',
      'photo.png',
    ]);
    expect(restored.first.finishedAt, DateTime(2026, 10, 7, 9, 30));
    expect(restored.first.savedFile?.path, endsWith('Downloads/notes.pdf'));
  });

  test('a removed entry stays removed after a restart', () async {
    final firstRun = await _openApp();
    final photo = _received('photo.png');
    final history = firstRun.read(recentTransfersProvider.notifier)
      ..record([photo, _received('notes.pdf')])
      ..remove(photo);
    await history.saved;

    final secondRun = await _openApp();

    expect(secondRun.read(recentTransfersProvider).single.name, 'notes.pdf');
  });

  test('clearing wipes the saved history but not the files', () async {
    final keptFile = File('${_folder.path}/Downloads/photo.png');
    await keptFile.create(recursive: true);
    final firstRun = await _openApp();
    final history = firstRun.read(recentTransfersProvider.notifier)
      ..record([_received('photo.png')])
      ..clear();
    await history.saved;

    final secondRun = await _openApp();

    expect(firstRun.read(recentTransfersProvider), isEmpty);
    expect(secondRun.read(recentTransfersProvider), isEmpty);
    expect(keptFile.existsSync(), isTrue);
  });
}
