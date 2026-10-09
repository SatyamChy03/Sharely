import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/design/widgets/icon_square_button.dart';
import 'package:sharely/design/widgets/section_label.dart';
import 'package:sharely/design/widgets/segmented_tabs.dart';
import 'package:sharely/design/widgets/surface_card.dart';
import 'package:sharely/features/transfer/state/activity_filter.dart';
import 'package:sharely/features/transfer/state/recent_transfers.dart';
import 'package:sharely/features/transfer/state/transfers_by_day.dart';
import 'package:sharely/features/transfer/widgets/clear_history_dialog.dart';
import 'package:sharely/features/transfer/widgets/transfer_row.dart';

/// The Activity tab (M12): every remembered transfer, grouped by day.
class ActivityTabView extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<ActivityTabView> createState() => _ActivityTabViewState();
}

class _ActivityTabViewState extends ConsumerState<ActivityTabView> {
  ActivityFilter _filter = ActivityFilter.all;

  Future<void> _clearAfterConfirming() async {
    if (!await confirmClearHistory(context)) return;
    ref.read(recentTransfersProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    final recent = ref.watch(recentTransfersProvider);
    final days = groupTransfersByDay(_filter.apply(recent));
    final textTheme = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(SharelySpacing.page),
      children: [
        SizedBox(
          height: SharelySizes.minTouchTarget,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Activity', style: textTheme.headlineMedium),
              if (recent.isNotEmpty)
                IconSquareButton(
                  icon: LucideIcons.trash2,
                  tooltip: 'Clear all',
                  onPressed: () => unawaited(_clearAfterConfirming()),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SegmentedTabs<ActivityFilter>(
          values: ActivityFilter.values,
          labelOf: (filter) => filter.label,
          selected: _filter,
          onSelected: (filter) => setState(() => _filter = filter),
        ),
        const SizedBox(height: 14),
        if (days.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: SharelySpacing.sm),
            child: Text(
              recent.isEmpty
                  ? 'Nothing yet. Files you send or receive show up here.'
                  : 'Nothing here. Switch the filter back to All.',
              style: textTheme.bodyMedium?.copyWith(
                color: SharelyColors.textSecondary,
              ),
            ),
          ),
        for (final day in days) ...[
          SectionLabel(day.label),
          const SizedBox(height: SharelySpacing.sm),
          SurfaceCard(
            radius: SharelyRadii.tile,
            padding: const EdgeInsets.all(SharelySpacing.xs),
            child: Column(
              children: [
                for (final transfer in day.transfers)
                  TransferRow(transfer: transfer),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
      ],
    );
  }
}
