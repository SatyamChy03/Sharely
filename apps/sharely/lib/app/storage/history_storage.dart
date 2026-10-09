import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sharely_core/sharely_core.dart';

final _log = Logger('HistoryStorage');

const _historyFileName = 'transfer_history.json';

/// Where history is saved; null keeps it in memory only, as tests do.
final historyStoreProvider = Provider<TransferHistoryStore?>((ref) => null);

/// The history read at startup, so the first frame already shows it.
final savedHistoryProvider = Provider<List<TransferHistoryEntry>>(
  (ref) => const [],
);

/// Opens the history file in the app's private folder and reads it.
Future<List<Override>> loadHistoryOverrides() async {
  final TransferHistoryStore store;
  try {
    final folder = await getApplicationSupportDirectory();
    store = TransferHistoryStore(
      File.fromUri(folder.uri.resolve(_historyFileName)),
    );
  } on Exception catch (error) {
    _log.severe('No private folder for history; keeping it in memory', error);
    return const [];
  }
  return [
    historyStoreProvider.overrideWithValue(store),
    savedHistoryProvider.overrideWithValue(await _readOrStartFresh(store)),
  ];
}

Future<List<TransferHistoryEntry>> _readOrStartFresh(
  TransferHistoryStore store,
) async {
  try {
    return await store.load();
  } on ProtocolException catch (error) {
    // A damaged history is never trusted; the next transfer replaces it.
    _log.warning('Discarding unreadable history', error);
  } on FileSystemException catch (error) {
    _log.warning('Could not read history', error);
  }
  return const [];
}
