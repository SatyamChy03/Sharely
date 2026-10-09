import 'package:flutter/material.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/design/typography.dart';
import 'package:sharely/features/transfer/state/send_state.dart';
import 'package:sharely/features/transfer/transfer_formatting.dart';
import 'package:sharely/features/transfer/widgets/transfer_progress_bar.dart';

/// The laptop's current send to the phone: waiting, progress or result.
class PhoneSendCard extends StatelessWidget {
  const new({
    required this.send,
    required this.phoneName,
    required this.onCancel,
    required this.onDismiss,
    super.key,
  });

  final SendWithFiles send;
  final String phoneName;
  final VoidCallback onCancel;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final send = this.send;
    final isRunning = send is! SendSucceeded && send is! SendFailed;
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
        decoration: const BoxDecoration(
          color: SharelyColors.surface,
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            Row(
              spacing: 12,
              children: [
                Expanded(child: _buildSummary(textTheme)),
                TextButton(
                  onPressed: isRunning ? onCancel : onDismiss,
                  child: Text(isRunning ? 'Cancel' : 'Done'),
                ),
              ],
            ),
            if (send is SendInProgress)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: TransferProgressBar(
                  fraction: send.fraction,
                  isOnDark: false,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary(TextTheme textTheme) {
    final (title, detail, isDetailMono) = _describe();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 2,
      children: [
        Text(title, style: textTheme.titleMedium),
        Text(
          detail,
          style: isDetailMono
              ? sharelyMonoStyle(size: 13, color: SharelyColors.slate)
              : textTheme.bodyMedium?.copyWith(color: SharelyColors.slate),
        ),
      ],
    );
  }

  (String title, String detail, bool isDetailMono) _describe() {
    final send = this.send;
    final files = formatFileCount(send.fileCount);
    final size = formatByteCount(send.totalBytes);
    return switch (send) {
      SendPreparing() || SendAwaitingAcceptance() => (
        'Waiting for $phoneName to accept',
        '$files · $size',
        true,
      ),
      SendInProgress(isReconnecting: true, :final bytesSent) => (
        'Reconnecting to $phoneName…',
        '${formatByteCount(bytesSent)} of $size sent. It continues by itself '
            'when the Wi-Fi is back.',
        false,
      ),
      SendInProgress(
        :final bytesSent,
        :final bytesPerSecond,
        :final timeLeft,
      ) =>
        (
          'Sending $files to $phoneName',
          [
            '${formatByteCount(bytesSent)} of $size',
            formatSpeed(bytesPerSecond),
            if (timeLeft != null) '${formatDurationShort(timeLeft)} left',
          ].join(' · '),
          true,
        ),
      SendSucceeded() => ('Sent $files to $phoneName', size, true),
      SendFailed(:final reason) => (
        "Couldn't send to $phoneName",
        describePhoneSendFailure(reason, phoneName),
        false,
      ),
    };
  }
}
