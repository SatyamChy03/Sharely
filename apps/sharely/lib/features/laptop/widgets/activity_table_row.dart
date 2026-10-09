import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/design/typography.dart';
import 'package:sharely/design/widgets/file_thumb.dart';
import 'package:sharely/design/widgets/status_badge.dart';
import 'package:sharely/features/laptop/open_folder.dart';
import 'package:sharely/features/transfer/state/recent_transfer.dart';
import 'package:sharely/features/transfer/transfer_formatting.dart';

/// One transfer as a table line: file, direction, size, time and status.
class ActivityTableRow extends StatelessWidget {
  const new({required this.transfer, this.onRemove, super.key});

  final RecentTransfer transfer;

  /// Shown as a small remove button; Activity passes it, Home does not.
  final VoidCallback? onRemove;

  static const _compactBelowWidth = 620.0;

  @override
  Widget build(BuildContext context) {
    final isSent = transfer.direction == TransferDirection.sent;
    final mono = sharelyMonoStyle(size: 12, color: SharelyColors.textSecondary);
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= _compactBelowWidth;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            spacing: 14,
            children: [
              FileThumb.forName(transfer.name, size: 36),
              Expanded(
                flex: 4,
                child: Text(
                  transfer.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
              if (isWide) Expanded(flex: 3, child: _Direction(isSent: isSent)),
              SizedBox(
                width: 76,
                child: Text(
                  formatByteCount(transfer.sizeBytes),
                  textAlign: TextAlign.end,
                  style: mono,
                ),
              ),
              if (isWide)
                SizedBox(
                  width: 52,
                  child: Text(
                    formatClockTime(transfer.finishedAt),
                    textAlign: TextAlign.end,
                    style: mono,
                  ),
                ),
              SizedBox(
                width: 92,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: StatusBadge(
                    label: isSent ? 'Sent' : 'Received',
                    tone: StatusTone.success,
                    icon: LucideIcons.check,
                    isPlain: true,
                  ),
                ),
              ),
              ..._buildActions(),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildActions() {
    final savedFile = transfer.savedFile;
    return [
      if (savedFile != null)
        TextButton(
          onPressed: () => unawaited(openFolder(savedFile.parent.path)),
          child: const Text('Show'),
        ),
      if (onRemove != null)
        IconButton(
          onPressed: onRemove,
          tooltip: 'Remove from activity',
          icon: const Icon(
            LucideIcons.x,
            size: 16,
            color: SharelyColors.textSecondary,
          ),
        ),
    ];
  }
}

class _Direction extends StatelessWidget {
  const new({required this.isSent});

  final bool isSent;

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: 6,
      children: [
        Icon(
          isSent ? LucideIcons.arrowUp : LucideIcons.arrowDown,
          size: 13,
          color: isSent ? SharelyColors.primary : SharelyColors.primarySoft,
        ),
        Flexible(
          child: Text(
            isSent ? 'To phone' : 'From phone',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: SharelyColors.textSecondary),
          ),
        ),
      ],
    );
  }
}
