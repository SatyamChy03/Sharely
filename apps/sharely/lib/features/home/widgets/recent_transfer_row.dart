import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/design/typography.dart';
import 'package:sharely/features/transfer/state/recent_transfer.dart';
import 'package:sharely/features/transfer/transfer_formatting.dart';

/// One finished file: direction, name, when, and size.
class RecentTransferRow extends StatelessWidget {
  const new({required this.transfer, this.onRemove, super.key});

  final RecentTransfer transfer;

  /// Shown as a small remove button; History passes it, Home does not.
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isSent = transfer.direction == TransferDirection.sent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        color: SharelyColors.surface,
        borderRadius: BorderRadius.all(Radius.circular(18)),
      ),
      child: Row(
        spacing: SharelySpacing.md,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isSent ? SharelyColors.ink : SharelyColors.mist,
              borderRadius: const BorderRadius.all(Radius.circular(11)),
            ),
            child: Icon(
              isSent ? LucideIcons.arrowUp : LucideIcons.arrowDown,
              size: 18,
              color: isSent ? SharelyColors.accentOnInk : SharelyColors.ink,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 1,
              children: [
                Text(
                  transfer.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyLarge?.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${isSent ? 'Sent' : 'Received'} · '
                  '${formatTimeAgo(transfer.finishedAt)}',
                  style: textTheme.bodySmall?.copyWith(
                    color: SharelyColors.slate,
                  ),
                ),
              ],
            ),
          ),
          Text(
            formatByteCount(transfer.sizeBytes),
            style: sharelyMonoStyle(size: 12, color: SharelyColors.slate),
          ),
          if (onRemove != null)
            IconButton(
              onPressed: onRemove,
              tooltip: 'Remove from history',
              constraints: const BoxConstraints.tightFor(
                width: SharelySizes.minTouchTarget,
                height: SharelySizes.minTouchTarget,
              ),
              icon: const Icon(
                LucideIcons.x,
                size: 16,
                color: SharelyColors.slate,
              ),
            ),
        ],
      ),
    );
  }
}
