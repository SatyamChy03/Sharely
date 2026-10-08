import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/features/home/widgets/recent_transfer_row.dart';
import 'package:sharely/features/transfer/state/recent_transfers.dart';

/// "Recent" on Home: the last three transfers, with a way to see them all.
class RecentSection extends ConsumerWidget {
  const new({required this.onSeeAll, super.key});

  final VoidCallback onSeeAll;

  static const _shownOnHome = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = ref.watch(recentTransfersProvider);
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: SharelySpacing.sm,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent',
              style: textTheme.titleMedium?.copyWith(fontSize: 17),
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
        for (final transfer in recent.take(_shownOnHome))
          RecentTransferRow(transfer: transfer),
      ],
    );
  }
}
