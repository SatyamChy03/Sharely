import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/features/home/widgets/recent_transfer_row.dart';
import 'package:sharely/features/transfer/state/recent_transfers.dart';
import 'package:sharely/features/transfer/widgets/clear_history_dialog.dart';

/// Every remembered transfer, newest first, with ways to remove them.
class HistoryTabView extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = ref.watch(recentTransfersProvider);
    final history = ref.read(recentTransfersProvider.notifier);
    final textTheme = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 104),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('History', style: textTheme.headlineMedium),
            if (recent.isNotEmpty)
              TextButton(
                onPressed: () => unawaited(_clearAfterConfirming(context, ref)),
                child: const Text('Clear all'),
              ),
          ],
        ),
        const SizedBox(height: SharelySpacing.lg),
        if (recent.isEmpty)
          Text(
            'Nothing yet. Files you send or receive show up here.',
            style: textTheme.bodyMedium?.copyWith(color: SharelyColors.slate),
          ),
        for (final transfer in recent)
          Padding(
            padding: const EdgeInsets.only(bottom: SharelySpacing.sm),
            child: RecentTransferRow(
              transfer: transfer,
              onRemove: () => history.remove(transfer),
            ),
          ),
      ],
    );
  }

  Future<void> _clearAfterConfirming(
    BuildContext context,
    WidgetRef ref,
  ) async {
    if (!await confirmClearHistory(context)) return;
    ref.read(recentTransfersProvider.notifier).clear();
  }
}
