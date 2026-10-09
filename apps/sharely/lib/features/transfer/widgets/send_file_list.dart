import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/design/typography.dart';
import 'package:sharely/design/widgets/file_thumb.dart';
import 'package:sharely/design/widgets/status_badge.dart';
import 'package:sharely/design/widgets/surface_card.dart';
import 'package:sharely/features/transfer/state/send_state.dart';
import 'package:sharely/features/transfer/transfer_formatting.dart';
import 'package:sharely/features/transfer/widgets/transfer_progress_bar.dart';

enum _FileProgress { done, current, waiting }

/// The queue of a send: each file is done, sending with a bar, or waiting.
class SendFileList extends StatelessWidget {
  const new({required this.files, required this.bytesSent, super.key});

  final List<SendFileInfo> files;
  final int bytesSent;

  static const _maxRows = 5;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final rows = <Widget>[];
    var bytesBefore = 0;
    var filesDone = 0;
    for (final file in files) {
      final sentOfFile = (bytesSent - bytesBefore).clamp(0, file.sizeBytes);
      bytesBefore += file.sizeBytes;
      final isDone = sentOfFile >= file.sizeBytes;
      if (isDone) filesDone++;
      if (rows.length >= _maxRows) continue;
      rows.add(
        _FileRow(
          file: file,
          progress: isDone
              ? _FileProgress.done
              : (sentOfFile > 0
                    ? _FileProgress.current
                    : _FileProgress.waiting),
          fraction: file.sizeBytes == 0 ? 0 : sentOfFile / file.sizeBytes,
        ),
      );
    }
    final hidden = files.length - rows.length;
    return SurfaceCard(
      radius: SharelyRadii.zone,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(textTheme, filesDone),
          ...rows,
          if (hidden > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 6),
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

  Widget _buildHeader(TextTheme textTheme, int filesDone) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Files', style: textTheme.labelMedium),
          Text(
            '$filesDone of ${files.length} done',
            style: textTheme.bodySmall?.copyWith(
              color: SharelyColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _FileRow extends StatelessWidget {
  const new({
    required this.file,
    required this.progress,
    required this.fraction,
  });

  final SendFileInfo file;
  final _FileProgress progress;
  final double fraction;

  @override
  Widget build(BuildContext context) {
    final isCurrent = progress == _FileProgress.current;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      child: Row(
        spacing: SharelySpacing.md,
        children: [
          FileThumb.forName(file.name, size: 36),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 4,
              children: [
                Row(
                  spacing: SharelySpacing.sm,
                  children: [
                    Expanded(
                      child: Text(
                        file.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              fontWeight: isCurrent
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
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
                if (isCurrent) TransferProgressBar(fraction: fraction),
              ],
            ),
          ),
          SizedBox(
            width: 78,
            child: Align(
              alignment: Alignment.centerRight,
              child: _buildStatus(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatus() => switch (progress) {
    _FileProgress.done => const StatusBadge(
      label: 'Done',
      tone: StatusTone.success,
      icon: LucideIcons.check,
      isPlain: true,
    ),
    _FileProgress.current => const StatusBadge(
      label: 'Sending',
      tone: StatusTone.connected,
      icon: LucideIcons.arrowUp,
      isPlain: true,
    ),
    _FileProgress.waiting => const StatusBadge(
      label: 'Waiting',
      tone: StatusTone.offline,
      icon: LucideIcons.clock,
      isPlain: true,
    ),
  };
}
