import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/design/typography.dart';
import 'package:sharely/design/widgets/file_thumb.dart';
import 'package:sharely/design/widgets/icon_square_button.dart';
import 'package:sharely/design/widgets/result_mark.dart';
import 'package:sharely/design/widgets/sharely_button.dart';
import 'package:sharely/design/widgets/surface_card.dart';
import 'package:sharely/features/transfer/state/send_state.dart';
import 'package:sharely/features/transfer/transfer_formatting.dart';

/// A send that ended (M10): complete with what went where, or why it failed.
class SendResultView extends StatelessWidget {
  const new({required this.send, required this.laptopName, super.key});

  final SendWithFiles send;
  final String laptopName;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final failure = switch (send) {
      SendFailed(:final reason) => reason,
      _ => null,
    };
    final isFailed = failure != null;
    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: IconSquareButton(
            icon: LucideIcons.x,
            tooltip: 'Close',
            onPressed: context.pop,
          ),
        ),
        const Gap(SharelySpacing.xl),
        _buildMark(isFailed: isFailed),
        const Gap(SharelySpacing.xl),
        Semantics(
          liveRegion: true,
          child: Text(
            isFailed ? "Couldn't send" : 'Transfer complete',
            textAlign: TextAlign.center,
            style: textTheme.headlineLarge,
          ),
        ),
        const Gap(SharelySpacing.sm),
        Text(
          '${formatFileCount(send.fileCount)} · '
          '${formatByteCount(send.totalBytes)}',
          style: sharelyMonoStyle(size: 15, color: SharelyColors.text),
        ),
        const Gap(SharelySpacing.sm),
        Text(
          failure == null
              ? 'Sent to $laptopName'
              : describeSendFailure(failure),
          textAlign: TextAlign.center,
          style: textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w400,
            color: SharelyColors.textSecondary,
          ),
        ),
        const Gap(28),
        if (!isFailed) _SentSummary(send: send, laptopName: laptopName),
        const Spacer(),
        SharelyButton(
          label: isFailed ? 'Back to home' : 'Done',
          onPressed: context.pop,
        ),
      ],
    );
  }

  Widget _buildMark({required bool isFailed}) {
    return ExcludeSemantics(
      child: ResultMark(
        size: 112,
        color: isFailed ? SharelyColors.danger : SharelyColors.success,
        icon: isFailed ? LucideIcons.x : LucideIcons.check,
      ),
    );
  }
}

class _SentSummary extends StatelessWidget {
  const new({required this.send, required this.laptopName});

  final SendWithFiles send;
  final String laptopName;

  static const _maxThumbs = 5;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SurfaceCard(
      radius: SharelyRadii.zone,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: SharelySpacing.md,
        children: [
          Row(
            spacing: 6,
            children: [
              for (final file in send.files.take(_maxThumbs))
                FileThumb.forName(file.name, size: 52),
            ],
          ),
          const Divider(height: 1, color: SharelyColors.line),
          Row(
            spacing: SharelySpacing.sm,
            children: [
              Text(
                'Saved to',
                style: textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w400,
                  color: SharelyColors.textSecondary,
                ),
              ),
              Expanded(
                child: Text(
                  'Downloads/Sharely on $laptopName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
