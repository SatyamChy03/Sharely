import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sharely/design/input_decoration.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/design/widgets/dashed_border.dart';
import 'package:sharely/design/widgets/icon_tile.dart';
import 'package:sharely/design/widgets/section_label.dart';
import 'package:sharely/design/widgets/segmented_tabs.dart';
import 'package:sharely/design/widgets/sharely_button.dart';
import 'package:sharely/design/widgets/surface_card.dart';
import 'package:sharely/features/laptop/widgets/activity_table_row.dart';
import 'package:sharely/features/laptop/widgets/laptop_page.dart';
import 'package:sharely/features/transfer/state/activity_filter.dart';
import 'package:sharely/features/transfer/state/recent_transfer.dart';
import 'package:sharely/features/transfer/state/recent_transfers.dart';
import 'package:sharely/features/transfer/state/transfers_by_day.dart';
import 'package:sharely/features/transfer/widgets/clear_history_dialog.dart';

/// Laptop Activity (D13): every remembered transfer, searchable, by day.
class LaptopActivityView extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<LaptopActivityView> createState() => _LaptopActivityViewState();
}

class _LaptopActivityViewState extends ConsumerState<LaptopActivityView> {
  ActivityFilter _filter = ActivityFilter.all;
  String _query = '';

  Future<void> _clearAfterConfirming() async {
    if (!await confirmClearHistory(context)) return;
    ref.read(recentTransfersProvider.notifier).clear();
  }

  List<RecentTransfer> _matching(List<RecentTransfer> transfers) {
    final query = _query.trim().toLowerCase();
    return [
      for (final transfer in _filter.apply(transfers))
        if (query.isEmpty || transfer.name.toLowerCase().contains(query))
          transfer,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final transfers = ref.watch(recentTransfersProvider);
    final days = groupTransfersByDay(_matching(transfers));
    final history = ref.read(recentTransfersProvider.notifier);
    return LaptopPage(
      children: [
        _buildHeader(hasTransfers: transfers.isNotEmpty),
        if (days.isEmpty)
          _EmptyActivity(hasTransfers: transfers.isNotEmpty)
        else
          SurfaceCard(
            padding: const EdgeInsets.all(SharelySpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final day in days) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                    child: SectionLabel(day.label),
                  ),
                  for (final transfer in day.transfers)
                    ActivityTableRow(
                      transfer: transfer,
                      onRemove: () => history.remove(transfer),
                    ),
                ],
              ],
            ),
          ),
        Text(
          'Activity is kept on this laptop only. Removing an entry never '
          'deletes the file.',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: SharelyColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildHeader({required bool hasTransfers}) {
    final textTheme = Theme.of(context).textTheme;
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: SharelySpacing.lg,
      runSpacing: SharelySpacing.lg,
      children: [
        Text('Activity', style: textTheme.headlineLarge),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 220,
              child: TextField(
                onChanged: (query) => setState(() => _query = query),
                style: textTheme.labelMedium,
                decoration: sharelyInputDecoration(
                  hintText: 'Search files',
                  prefixIcon: const Icon(LucideIcons.search, size: 16),
                ).copyWith(fillColor: SharelyColors.surface),
              ),
            ),
            SegmentedTabs<ActivityFilter>(
              values: ActivityFilter.values,
              labelOf: (filter) => filter.label,
              selected: _filter,
              isExpanded: false,
              onSelected: (filter) => setState(() => _filter = filter),
            ),
            if (hasTransfers)
              SharelyButton(
                label: 'Clear all',
                leadingIcon: LucideIcons.trash2,
                variant: SharelyButtonVariant.ghost,
                height: 40,
                isExpanded: false,
                onPressed: () => unawaited(_clearAfterConfirming()),
              ),
          ],
        ),
      ],
    );
  }
}

class _EmptyActivity extends StatelessWidget {
  const new({required this.hasTransfers});

  /// True when transfers exist but none match the search or filter.
  final bool hasTransfers;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return DashedBorder(
      color: SharelyColors.lineStrong,
      radius: 16,
      strokeWidth: 1.5,
      child: Padding(
        padding: const EdgeInsets.all(SharelySpacing.xxl),
        child: Center(
          child: Column(
            spacing: SharelySpacing.md,
            children: [
              const IconTile(
                icon: LucideIcons.clock,
                size: 56,
                radius: SharelyRadii.tile,
                color: SharelyColors.textSecondary,
                background: SharelyColors.surface,
              ),
              Text(
                hasTransfers ? 'Nothing matches' : 'No transfers yet',
                style: textTheme.titleLarge,
              ),
              Text(
                hasTransfers
                    ? 'Try another name or switch the filter back to All.'
                    : 'Files you send or receive will appear here.',
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: SharelyColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
