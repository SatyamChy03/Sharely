import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/design/typography.dart';
import 'package:sharely/features/laptop/widgets/activity_row.dart';
import 'package:sharely/features/transfer/state/recent_transfer.dart';
import 'package:sharely/features/transfer/state/recent_transfers.dart';

/// Laptop "Activity": transfers grouped into Today, Yesterday and Earlier.
class ActivityPanel extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = ref.watch(recentTransfersProvider);
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: const BoxDecoration(
        color: SharelyColors.surface,
        borderRadius: BorderRadius.all(SharelyRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 14,
        children: [
          Text(
            'Activity',
            style: textTheme.titleMedium?.copyWith(fontSize: 18),
          ),
          if (recent.isEmpty)
            Text(
              'Nothing yet. Files from your phone show up here.',
              style: textTheme.bodyMedium?.copyWith(color: SharelyColors.slate),
            ),
          for (final (label, transfers) in _groupByDay(recent)) ...[
            Text(
              label,
              style: sharelyMonoStyle(
                size: 11,
                color: SharelyColors.slate,
              ).copyWith(letterSpacing: 1.5),
            ),
            for (final transfer in transfers) ActivityRow(transfer: transfer),
          ],
        ],
      ),
    );
  }

  static List<(String, List<RecentTransfer>)> _groupByDay(
    List<RecentTransfer> transfers,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    String labelFor(DateTime moment) {
      if (!moment.isBefore(today)) return 'TODAY';
      if (!moment.isBefore(yesterday)) return 'YESTERDAY';
      return 'EARLIER';
    }

    final groups = <String, List<RecentTransfer>>{};
    for (final transfer in transfers) {
      groups.putIfAbsent(labelFor(transfer.finishedAt), () => []).add(transfer);
    }
    return [for (final MapEntry(:key, :value) in groups.entries) (key, value)];
  }
}
