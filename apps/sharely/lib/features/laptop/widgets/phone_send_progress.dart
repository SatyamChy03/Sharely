import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/design/typography.dart';
import 'package:sharely/design/widgets/icon_tile.dart';
import 'package:sharely/design/widgets/sharely_button.dart';
import 'package:sharely/design/widgets/surface_card.dart';
import 'package:sharely/features/transfer/state/send_state.dart';
import 'package:sharely/features/transfer/transfer_formatting.dart';
import 'package:sharely/features/transfer/widgets/transfer_progress_bar.dart';

/// A running send to the phone (D09, D17): percent, bar, numbers and Cancel.
class PhoneSendProgress extends StatelessWidget {
  const new({
    required this.send,
    required this.phoneName,
    required this.onCancel,
    super.key,
  });

  final SendWithFiles send;
  final String phoneName;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final progress = switch (send) {
      SendInProgress() && final running => running,
      _ => null,
    };
    final isReconnecting = progress?.isReconnecting ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: SharelySpacing.page,
      children: [
        if (isReconnecting) _InterruptedBanner(phoneName: phoneName),
        SurfaceCard(
          padding: const EdgeInsets.all(SharelySpacing.xl),
          child: Semantics(
            container: true,
            liveRegion: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: SharelySpacing.page,
              children: [
                _buildHeadline(context, progress),
                TransferProgressBar(
                  fraction: progress?.fraction ?? 0,
                  height: 10,
                  isStalled: isReconnecting,
                ),
                _buildStats(context, progress),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeadline(BuildContext context, SendInProgress? progress) {
    final textTheme = Theme.of(context).textTheme;
    final percent = ((progress?.fraction ?? 0) * 100).floor();
    final isStalled = progress?.isReconnecting ?? false;
    final caption = switch (send) {
      SendInProgress(isReconnecting: true) => 'Paused · reconnecting',
      SendInProgress() => 'Sending ${formatFileCount(send.fileCount)}',
      _ => 'Waiting for $phoneName to accept',
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      spacing: 14,
      children: [
        Text.rich(
          TextSpan(
            text: '$percent',
            children: const [
              TextSpan(
                text: '%',
                style: TextStyle(
                  fontSize: 30,
                  letterSpacing: 0,
                  color: SharelyColors.textSecondary,
                ),
              ),
            ],
          ),
          style: textTheme.displayLarge?.copyWith(
            fontSize: 64,
            letterSpacing: -2.5,
            height: 1,
            color: isStalled ? SharelyColors.textSecondary : SharelyColors.text,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              caption,
              style: textTheme.bodyMedium?.copyWith(
                color: SharelyColors.textSecondary,
              ),
            ),
          ),
        ),
        SharelyButton(
          label: 'Cancel',
          variant: SharelyButtonVariant.danger,
          height: 40,
          isExpanded: false,
          onPressed: onCancel,
        ),
      ],
    );
  }

  Widget _buildStats(BuildContext context, SendInProgress? progress) {
    final isStalled = progress?.isReconnecting ?? false;
    final speed = progress == null || isStalled || progress.bytesPerSecond <= 0
        ? '—'
        : formatSpeed(progress.bytesPerSecond);
    final timeLeft = switch (progress?.timeLeft) {
      final left? when !isStalled => '~${formatDurationShort(left)}',
      _ => isStalled ? 'Paused' : '—',
    };
    return Wrap(
      spacing: SharelySpacing.huge,
      runSpacing: SharelySpacing.lg,
      children: [
        _Stat(
          label: 'Transferred',
          value:
              '${formatByteCount(progress?.bytesSent ?? 0)} / '
              '${formatByteCount(send.totalBytes)}',
        ),
        _Stat(label: 'Speed', value: speed),
        _Stat(label: 'Time remaining', value: timeLeft),
        _Stat(label: 'Destination', value: phoneName, isMono: false),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const new({required this.label, required this.value, this.isMono = true});

  final String label;
  final String value;
  final bool isMono;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      spacing: 4,
      children: [
        Text(
          label,
          style: textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w500,
            color: SharelyColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: isMono
              ? sharelyMonoStyle(size: 18, color: SharelyColors.text)
              : textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

class _InterruptedBanner extends StatelessWidget {
  const new({required this.phoneName});

  final String phoneName;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SurfaceCard(
      radius: SharelyRadii.zone,
      color: SharelyColors.dangerSurface,
      borderColor: SharelyColors.dangerLine,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        spacing: SharelySpacing.lg,
        children: [
          const IconTile(
            icon: LucideIcons.wifiOff,
            size: 40,
            color: SharelyColors.dangerText,
            background: SharelyColors.dangerTint,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 3,
              children: [
                Text('Transfer interrupted', style: textTheme.labelLarge),
                Text(
                  '$phoneName went offline. What was already sent is kept, '
                  'and the send continues by itself when the Wi-Fi is back.',
                  style: textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w400,
                    color: SharelyColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
