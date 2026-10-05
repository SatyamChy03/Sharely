import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sharely/features/transfer/state/recent_transfer.dart';

// Session-only until transfer history is stored on disk (PRD M6).
const _maxRecent = 50;

final recentTransfersProvider =
    NotifierProvider<RecentTransfers, List<RecentTransfer>>(
      RecentTransfers.new,
    );

/// Finished transfers this session, newest first.
class RecentTransfers extends Notifier<List<RecentTransfer>> {
  @override
  List<RecentTransfer> build() => const [];

  void record(Iterable<RecentTransfer> finished) {
    state = List.unmodifiable([...finished, ...state].take(_maxRecent));
  }
}
