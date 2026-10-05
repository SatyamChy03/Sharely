import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/features/home/widgets/recent_transfer_row.dart';
import 'package:sharely/features/transfer/state/recent_transfers.dart';

/// Every transfer from this session, newest first.
class HistoryTabView extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = ref.watch(recentTransfersProvider);
    final textTheme = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 104),
      children: [
        Text('History', style: textTheme.headlineMedium),
        const SizedBox(height: SharelySpacing.lg),
        if (recent.isEmpty)
          Text(
            'Nothing sent yet. Files you send show up here.',
            style: textTheme.bodyMedium?.copyWith(color: SharelyColors.slate),
          ),
        for (final transfer in recent)
          Padding(
            padding: const EdgeInsets.only(bottom: SharelySpacing.sm),
            child: RecentTransferRow(transfer: transfer),
          ),
      ],
    );
  }
}
