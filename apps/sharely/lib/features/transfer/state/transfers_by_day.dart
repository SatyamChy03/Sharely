import 'package:sharely/features/transfer/state/recent_transfer.dart';

typedef TransfersOfDay = ({String label, List<RecentTransfer> transfers});

/// Splits [transfers] into Today, Yesterday and Earlier, keeping their order.
List<TransfersOfDay> groupTransfersByDay(
  List<RecentTransfer> transfers, {
  DateTime? now,
}) {
  final moment = now ?? DateTime.now();
  final today = DateTime(moment.year, moment.month, moment.day);
  final yesterday = today.subtract(const Duration(days: 1));
  String labelFor(DateTime finishedAt) {
    if (!finishedAt.isBefore(today)) return 'TODAY';
    if (!finishedAt.isBefore(yesterday)) return 'YESTERDAY';
    return 'EARLIER';
  }

  final groups = <String, List<RecentTransfer>>{};
  for (final transfer in transfers) {
    groups.putIfAbsent(labelFor(transfer.finishedAt), () => []).add(transfer);
  }
  return [
    for (final MapEntry(:key, :value) in groups.entries)
      (label: key, transfers: value),
  ];
}
