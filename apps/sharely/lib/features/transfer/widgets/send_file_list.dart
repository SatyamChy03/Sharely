import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/design/typography.dart';
import 'package:sharely/features/transfer/state/send_state.dart';

enum _FileProgress { done, current, queued }

/// Each file in the send: done, in progress with its percent, or queued.
class SendFileList extends StatelessWidget {
  const new({required this.files, required this.bytesSent, super.key});

  final List<SendFileInfo> files;
  final int bytesSent;

  static const _maxRows = 5;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    var bytesBefore = 0;
    for (final file in files.take(_maxRows)) {
      final sentOfFile = (bytesSent - bytesBefore).clamp(0, file.sizeBytes);
      bytesBefore += file.sizeBytes;
      final progress = sentOfFile >= file.sizeBytes
          ? _FileProgress.done
          : sentOfFile > 0
          ? _FileProgress.current
          : _FileProgress.queued;
      final percent = file.sizeBytes == 0
          ? 0
          : sentOfFile * 100 ~/ file.sizeBytes;
      rows.add(_FileRow(name: file.name, progress: progress, percent: percent));
    }
    final hidden = files.length - _maxRows;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 2,
      children: [
        ...rows,
        if (hidden > 0)
          Padding(
            padding: const EdgeInsets.only(left: 36, top: 4),
            child: Text(
              'and $hidden more',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: SharelyColors.onInkMuted),
            ),
          ),
      ],
    );
  }
}

class _FileRow extends StatelessWidget {
  const new({
    required this.name,
    required this.progress,
    required this.percent,
  });

  final String name;
  final _FileProgress progress;
  final int percent;

  @override
  Widget build(BuildContext context) {
    final (dotColor, textColor, status) = switch (progress) {
      _FileProgress.done => (
        SharelyColors.accent,
        SharelyColors.surface,
        'done',
      ),
      _FileProgress.current => (
        SharelyColors.surface,
        SharelyColors.surface,
        '$percent%',
      ),
      _FileProgress.queued => (
        SharelyColors.inkBorderStrong,
        SharelyColors.onInkMuted,
        'queued',
      ),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 10),
      child: Row(
        spacing: SharelySpacing.md,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
            child: progress == _FileProgress.done
                ? const Icon(
                    LucideIcons.check,
                    size: 13,
                    color: SharelyColors.ink,
                  )
                : null,
          ),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyLarge
                  ?.copyWith(fontSize: 15, color: textColor),
            ),
          ),
          Text(
            status,
            style: sharelyMonoStyle(size: 12, color: SharelyColors.onInkMuted),
          ),
        ],
      ),
    );
  }
}
