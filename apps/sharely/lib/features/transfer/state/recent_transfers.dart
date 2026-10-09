import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:sharely/app/storage/history_storage.dart';
import 'package:sharely/features/transfer/state/recent_transfer.dart';
import 'package:sharely_core/sharely_core.dart';

final _log = Logger('History');

final recentTransfersProvider =
    NotifierProvider<RecentTransfers, List<RecentTransfer>>(
      RecentTransfers.new,
    );

/// Finished transfers, newest first, saved so they survive a restart.
class RecentTransfers extends Notifier<List<RecentTransfer>> {
  // Saves run one after another so an older list never lands last.
  Future<void> _lastSave = Future.value();

  @override
  List<RecentTransfer> build() => List.unmodifiable(
    ref.read(savedHistoryProvider).map(RecentTransfer.fromHistory),
  );

  /// Resolves once every change so far is on disk.
  Future<void> get saved => _lastSave;

  void record(Iterable<RecentTransfer> finished) {
    _replaceWith([...finished, ...state].take(maxHistoryEntries));
  }

  /// Forgets one entry; the file it names is left untouched.
  void remove(RecentTransfer transfer) {
    _replaceWith(state.where((existing) => !identical(existing, transfer)));
  }

  /// Forgets every entry; the files they name are left untouched.
  void clear() {
    state = const [];
    final store = ref.read(historyStoreProvider);
    if (store != null) _saveInOrder(store.clear);
  }

  void _replaceWith(Iterable<RecentTransfer> transfers) {
    final updated = List<RecentTransfer>.unmodifiable(transfers);
    state = updated;
    final store = ref.read(historyStoreProvider);
    if (store == null) return;
    final entries = [for (final transfer in updated) transfer.toHistory()];
    _saveInOrder(() => store.save(entries));
  }

  void _saveInOrder(Future<void> Function() save) {
    _lastSave = _lastSave.then((_) async {
      try {
        await save();
      } on FileSystemException catch (error) {
        // The list still shows this session; it just won't survive a restart.
        _log.severe('Could not save history', error);
      }
    });
  }
}
