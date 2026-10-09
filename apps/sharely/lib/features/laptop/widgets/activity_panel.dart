import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/features/laptop/widgets/activity_day_groups.dart';
import 'package:sharely/features/transfer/state/recent_transfers.dart';

/// Laptop "Activity": the latest transfers, with the rest under History.
class ActivityPanel extends ConsumerWidget {
  const new({required this.onSeeAll, super.key});

  final VoidCallback onSeeAll;

  static const _shownOnHome = 6;

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Activity',
                style: textTheme.titleMedium?.copyWith(fontSize: 18),
              ),
              if (recent.isNotEmpty)
                TextButton(onPressed: onSeeAll, child: const Text('See all')),
            ],
          ),
          if (recent.isEmpty)
            Text(
              'Nothing yet. Files you send or receive show up here.',
              style: textTheme.bodyMedium?.copyWith(color: SharelyColors.slate),
            ),
          ActivityDayGroups(transfers: recent.take(_shownOnHome).toList()),
        ],
      ),
    );
  }
}
