import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/design/typography.dart';
import 'package:sharely/design/widgets/file_thumb.dart';
import 'package:sharely/design/widgets/status_badge.dart';
import 'package:sharely/features/transfer/state/recent_transfer.dart';
import 'package:sharely/features/transfer/transfer_formatting.dart';

/// One finished file: thumbnail, name, size and time, and which way it went.
class TransferRow extends StatelessWidget {
  const new({
    required this.transfer,
    super.key,
    this.thumbSize = 40,
    this.background,
  });

  final RecentTransfer transfer;
  final double thumbSize;

  /// Set where the row stands alone instead of inside a card.
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final isSent = transfer.direction == TransferDirection.sent;
    return Container(
      padding: const EdgeInsets.all(SharelySpacing.sm),
      decoration: BoxDecoration(
        color: background,
        borderRadius: const BorderRadius.all(SharelyRadii.row),
      ),
      child: Row(
        spacing: SharelySpacing.md,
        children: [
          FileThumb.forName(transfer.name, size: thumbSize),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 3,
              children: [
                Text(
                  transfer.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w500),
                ),
                Text(
                  '${formatByteCount(transfer.sizeBytes)} · '
                  '${formatClockTime(transfer.finishedAt)}',
                  style: sharelyMonoStyle(
                    size: 12,
                    color: SharelyColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          StatusBadge(
            label: isSent ? 'Sent' : 'Received',
            tone: isSent ? StatusTone.success : StatusTone.connected,
            icon: isSent ? LucideIcons.check : LucideIcons.arrowDown,
            isPlain: true,
          ),
        ],
      ),
    );
  }
}
