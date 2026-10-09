import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/design/typography.dart';
import 'package:sharely/design/widgets/file_thumb.dart';
import 'package:sharely/design/widgets/result_mark.dart';
import 'package:sharely/design/widgets/sharely_button.dart';
import 'package:sharely/design/widgets/surface_card.dart';
import 'package:sharely/features/transfer/state/send_state.dart';
import 'package:sharely/features/transfer/transfer_formatting.dart';
import 'package:sharely_core/sharely_core.dart';

/// A send to the phone that ended (D10): complete, or why it stopped.
class PhoneSendResult extends StatelessWidget {
  const new({
    required this.send,
    required this.phoneName,
    required this.onDone,
    super.key,
  });

  final SendWithFiles send;
  final String phoneName;

  /// Clears the result so the next send can start.
  final VoidCallback onDone;

  static const _maxRows = 6;

  @override
  Widget build(BuildContext context) {
    final failure = switch (send) {
      SendFailed(:final reason) => reason,
      _ => null,
    };
    final isFailed = failure != null;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Semantics(
          container: true,
          liveRegion: true,
          child: Column(
            children: [
              ExcludeSemantics(
                child: ResultMark(
                  size: 112,
                  color: isFailed
                      ? SharelyColors.danger
                      : SharelyColors.success,
                  icon: isFailed ? LucideIcons.x : LucideIcons.check,
                ),
              ),
              const Gap(28),
              ..._buildSummary(context, failure),
              const Gap(28),
              if (!isFailed) _buildFiles(context),
              const Gap(28),
              SharelyButton(
                label: isFailed ? 'Try again' : 'Send more',
                leadingIcon: isFailed
                    ? LucideIcons.refreshCw
                    : LucideIcons.arrowUp,
                height: 48,
                isExpanded: false,
                onPressed: onDone,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFiles(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final hidden = send.files.length - _maxRows;
    return SurfaceCard(
      padding: const EdgeInsets.all(SharelySpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final file in send.files.take(_maxRows))
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              child: Row(
                spacing: SharelySpacing.md,
                children: [
                  FileThumb.forName(file.name, size: 32),
                  Expanded(
                    child: Text(
                      file.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.labelMedium,
                    ),
                  ),
                  Text(
                    formatByteCount(file.sizeBytes),
                    style: sharelyMonoStyle(
                      size: 12,
                      color: SharelyColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          if (hidden > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 2, 10, 8),
              child: Text(
                'and $hidden more',
                style: textTheme.bodySmall?.copyWith(
                  color: SharelyColors.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildSummary(BuildContext context, TransferFailure? failure) {
    final textTheme = Theme.of(context).textTheme;
    final isFailed = failure != null;
    return [
      Text(
        isFailed ? "Couldn't send" : 'Transfer complete',
        textAlign: TextAlign.center,
        style: textTheme.displaySmall?.copyWith(fontSize: 36),
      ),
      const Gap(SharelySpacing.sm),
      if (send.files.isNotEmpty)
        Text(
          '${formatFileCount(send.fileCount)} · '
          '${formatByteCount(send.totalBytes)}',
          style: sharelyMonoStyle(size: 16, color: SharelyColors.text),
        ),
      const Gap(SharelySpacing.sm),
      Text(
        failure == null
            ? 'Sent to $phoneName'
            : describePhoneSendFailure(failure, phoneName),
        textAlign: TextAlign.center,
        style: textTheme.bodyMedium?.copyWith(
          color: SharelyColors.textSecondary,
        ),
      ),
    ];
  }
}
