import 'package:flutter/material.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/design/typography.dart';
import 'package:sharely/design/widgets/file_thumb.dart';
import 'package:sharely/design/widgets/surface_card.dart';
import 'package:sharely/features/transfer/state/incoming_transfer_view.dart';
import 'package:sharely/features/transfer/transfer_formatting.dart';
import 'package:sharely/features/transfer/widgets/transfer_progress_bar.dart';

/// One transfer arriving right now, with its progress and a way to stop it.
class ReceivingCard extends StatelessWidget {
  const new({required this.view, required this.onCancel, super.key});

  final IncomingTransferView view;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: SharelySpacing.md,
        children: [
          Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    text: view.isReconnecting
                        ? 'Reconnecting '
                        : 'Receiving now ',
                    children: [
                      TextSpan(
                        text: 'from ${view.senderName}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w400,
                          color: SharelyColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  style: textTheme.titleSmall,
                ),
              ),
              TextButton(
                onPressed: onCancel,
                style: TextButton.styleFrom(
                  foregroundColor: SharelyColors.dangerText,
                ),
                child: const Text('Cancel'),
              ),
            ],
          ),
          _buildProgress(textTheme),
        ],
      ),
    );
  }

  Widget _buildProgress(TextTheme textTheme) {
    final percent = (view.fraction * 100).floor();
    return Row(
      spacing: 14,
      children: [
        FileThumb.forName(view.fileNames.firstOrNull ?? '', size: 44),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: SharelySpacing.sm,
            children: [
              Row(
                spacing: SharelySpacing.md,
                children: [
                  Expanded(
                    child: Text(
                      formatFileCount(view.fileNames.length),
                      style: textTheme.labelMedium,
                    ),
                  ),
                  Text(
                    '${formatByteCount(view.bytesReceived)} / '
                    '${formatByteCount(view.totalBytes)}',
                    style: sharelyMonoStyle(
                      size: 12,
                      color: SharelyColors.textSecondary,
                    ),
                  ),
                ],
              ),
              TransferProgressBar(
                fraction: view.fraction,
                height: 6,
                isStalled: view.isReconnecting,
              ),
            ],
          ),
        ),
        SizedBox(
          width: 44,
          child: Text(
            '$percent%',
            textAlign: TextAlign.end,
            style: sharelyMonoStyle(size: 15, color: SharelyColors.primary),
          ),
        ),
      ],
    );
  }
}
