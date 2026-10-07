import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/design/typography.dart';
import 'package:sharely/features/laptop/widgets/activity_day_groups.dart';
import 'package:sharely/features/transfer/state/recent_transfer.dart';
import 'package:sharely/features/transfer/state/recent_transfers.dart';
import 'package:sharely/features/transfer/transfer_formatting.dart';
import 'package:sharely/features/transfer/widgets/clear_history_dialog.dart';

/// Laptop "History": every remembered transfer by day, and removing them.
class LaptopHistoryView extends ConsumerWidget {
  const new({super.key});

  static const _maxContentWidth = 760.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transfers = ref.watch(recentTransfersProvider);
    final textTheme = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxContentWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 18,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'History',
                    style: textTheme.headlineMedium?.copyWith(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.2,
                    ),
                  ),
                  if (transfers.isNotEmpty)
                    TextButton(
                      onPressed: () =>
                          unawaited(_clearAfterConfirming(context, ref)),
                      child: const Text('Clear history'),
                    ),
                ],
              ),
              if (transfers.isNotEmpty)
                Text(
                  _summarise(transfers),
                  style: sharelyMonoStyle(size: 13, color: SharelyColors.slate),
                ),
              _HistoryCard(
                transfers: transfers,
                onRemove: ref.read(recentTransfersProvider.notifier).remove,
              ),
              Text(
                'History is kept on this laptop only. Removing an entry never '
                'deletes the file.',
                style: textTheme.bodySmall?.copyWith(
                  color: SharelyColors.slate,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _clearAfterConfirming(
    BuildContext context,
    WidgetRef ref,
  ) async {
    if (!await confirmClearHistory(context)) return;
    ref.read(recentTransfersProvider.notifier).clear();
  }

  static String _summarise(List<RecentTransfer> transfers) {
    final totalBytes = transfers.fold(0, (sum, item) => sum + item.sizeBytes);
    return '${formatFileCount(transfers.length)} · '
        '${formatByteCount(totalBytes)}';
  }
}

class _HistoryCard extends StatelessWidget {
  const new({required this.transfers, required this.onRemove});

  final List<RecentTransfer> transfers;
  final ValueChanged<RecentTransfer> onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: const BoxDecoration(
        color: SharelyColors.surface,
        borderRadius: BorderRadius.all(SharelyRadii.card),
      ),
      child: transfers.isEmpty
          ? const _EmptyHistory()
          : ActivityDayGroups(
              transfers: transfers,
              showsTime: true,
              onRemove: onRemove,
            ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SharelySpacing.xxl),
      child: Column(
        spacing: SharelySpacing.md,
        children: [
          const Icon(LucideIcons.clock, size: 28, color: SharelyColors.slate),
          Text('Nothing here yet', style: textTheme.titleMedium),
          Text(
            'Files your phone sends to this laptop are listed here.',
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(color: SharelyColors.slate),
          ),
        ],
      ),
    );
  }
}
