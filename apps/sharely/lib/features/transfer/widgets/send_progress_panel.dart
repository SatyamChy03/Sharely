import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/design/typography.dart';
import 'package:sharely/features/transfer/state/send_state.dart';
import 'package:sharely/features/transfer/transfer_formatting.dart';
import 'package:sharely/features/transfer/widgets/transfer_progress_bar.dart';

/// The middle of the sending screen: an icon, what's happening, progress.
class SendProgressPanel extends StatelessWidget {
  const new({required this.send, required this.laptopName, super.key});

  final SendState send;
  final String laptopName;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final (icon, title, message) = _describe();
    final progress = send;
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: SharelySpacing.md,
      children: [
        _StageBadge(icon: icon),
        const SizedBox(height: SharelySpacing.sm),
        Text(
          title,
          textAlign: TextAlign.center,
          style: textTheme.headlineMedium,
        ),
        Text(
          message,
          textAlign: TextAlign.center,
          style: textTheme.bodyLarge?.copyWith(color: SharelyColors.onInkSoft),
        ),
        if (progress is SendInProgress) ...[
          const SizedBox(height: SharelySpacing.lg),
          Text(
            '${(progress.fraction * 100).floor()}%',
            style: sharelyMonoStyle(size: 44, color: SharelyColors.surface),
          ),
          TransferProgressBar(fraction: progress.fraction),
          Text(
            _progressDetail(progress),
            style: sharelyMonoStyle(size: 13, color: SharelyColors.onInkMuted),
          ),
        ],
      ],
    );
  }

  (IconData, String, String) _describe() {
    final summary = switch (send) {
      SendWithFiles(:final fileCount, :final totalBytes) =>
        '${formatFileCount(fileCount)} · ${formatByteCount(totalBytes)}',
      SendIdle() => '',
    };
    return switch (send) {
      SendIdle() || SendPreparing() => (
        LucideIcons.fileSearch,
        'Getting files ready…',
        summary,
      ),
      SendAwaitingAcceptance() => (
        LucideIcons.laptop,
        'Waiting for $laptopName',
        'Accept on the laptop to start. $summary',
      ),
      SendInProgress() => (
        LucideIcons.arrowUp,
        'Sending to $laptopName',
        summary,
      ),
      SendSucceeded() => (
        LucideIcons.circleCheck,
        'Sent!',
        '$summary saved in Downloads/Sharely on $laptopName.',
      ),
      SendFailed(:final reason) => (
        LucideIcons.circleAlert,
        "Couldn't send",
        describeSendFailure(reason),
      ),
    };
  }

  String _progressDetail(SendInProgress progress) {
    final sent =
        '${formatByteCount(progress.bytesSent)} of '
        '${formatByteCount(progress.totalBytes)}';
    final timeLeft = progress.timeLeft;
    if (progress.bytesPerSecond <= 0 || timeLeft == null) return sent;
    return '$sent · ${formatSpeed(progress.bytesPerSecond)} · '
        '${formatTimeLeft(timeLeft)}';
  }
}

class _StageBadge extends StatelessWidget {
  const new({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: SharelyMotion.medium,
      child: Container(
        key: ValueKey(icon),
        width: 88,
        height: 88,
        decoration: const BoxDecoration(
          color: SharelyColors.inkRaised,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 38, color: SharelyColors.accentOnInk),
      ),
    );
  }
}
