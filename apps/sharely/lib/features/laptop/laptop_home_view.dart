import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/design/widgets/sharely_button.dart';
import 'package:sharely/design/widgets/status_badge.dart';
import 'package:sharely/design/widgets/surface_card.dart';
import 'package:sharely/features/laptop/widgets/activity_table_row.dart';
import 'package:sharely/features/laptop/widgets/laptop_page.dart';
import 'package:sharely/features/laptop/widgets/send_panel.dart';
import 'package:sharely/features/transfer/state/recent_transfer.dart';
import 'package:sharely/features/transfer/state/recent_transfers.dart';

/// Laptop Home (D05): who files go to, the drop zone, and recent transfers.
class LaptopHomeView extends ConsumerWidget {
  const new({
    required this.phoneName,
    required this.isConnected,
    required this.onChangeDevice,
    required this.onViewAll,
    super.key,
  });

  final String phoneName;
  final bool isConnected;
  final VoidCallback onChangeDevice;
  final VoidCallback onViewAll;

  static const _recentShown = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = ref.watch(recentTransfersProvider);
    return LaptopPage(
      children: [
        _Header(
          phoneName: phoneName,
          isConnected: isConnected,
          onChangeDevice: onChangeDevice,
        ),
        SendPanel(phoneName: phoneName, isConnected: isConnected),
        _RecentCard(
          recent: recent.take(_recentShown).toList(),
          onViewAll: onViewAll,
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const new({
    required this.phoneName,
    required this.isConnected,
    required this.onChangeDevice,
  });

  final String phoneName;
  final bool isConnected;
  final VoidCallback onChangeDevice;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final title = _buildTitle(textTheme);
    final status = Row(
      mainAxisSize: MainAxisSize.min,
      spacing: SharelySpacing.lg,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          spacing: 4,
          children: [
            StatusBadge(
              label: isConnected ? 'Connected' : 'Disconnected',
              tone: isConnected ? StatusTone.connected : StatusTone.offline,
            ),
            Text(
              isConnected ? 'Wi-Fi · Direct' : 'Waiting for the phone',
              style: textTheme.bodySmall?.copyWith(
                color: SharelyColors.textSecondary,
              ),
            ),
          ],
        ),
        SharelyButton(
          label: 'Change device',
          variant: SharelyButtonVariant.secondary,
          height: 40,
          isExpanded: false,
          onPressed: onChangeDevice,
        ),
      ],
    );
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.end,
      spacing: SharelySpacing.lg,
      runSpacing: SharelySpacing.lg,
      children: [title, status],
    );
  }

  Widget _buildTitle(TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      spacing: 6,
      children: [
        Text(
          'Send files to',
          style: textTheme.labelMedium?.copyWith(
            color: SharelyColors.textSecondary,
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          spacing: SharelySpacing.md,
          children: [
            Icon(
              LucideIcons.smartphone,
              size: 28,
              color: isConnected
                  ? SharelyColors.primary
                  : SharelyColors.textSecondary,
            ),
            Flexible(
              child: Text(
                phoneName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.displaySmall,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RecentHeader extends StatelessWidget {
  const new({required this.onViewAll});

  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Recent', style: Theme.of(context).textTheme.labelLarge),
          if (onViewAll != null)
            TextButton(onPressed: onViewAll, child: const Text('View all')),
        ],
      ),
    );
  }
}

class _RecentCard extends StatelessWidget {
  const new({required this.recent, required this.onViewAll});

  final List<RecentTransfer> recent;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.all(SharelySpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _RecentHeader(onViewAll: recent.isEmpty ? null : onViewAll),
          if (recent.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Text(
                'Files you send or receive will appear here.',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: SharelyColors.textSecondary),
              ),
            ),
          for (final transfer in recent) ActivityTableRow(transfer: transfer),
        ],
      ),
    );
  }
}
