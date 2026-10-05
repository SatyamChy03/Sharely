import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/features/transfer/state/incoming_transfer_view.dart';
import 'package:sharely/features/transfer/state/incoming_transfers_controller.dart';
import 'package:sharely/features/transfer/transfer_formatting.dart';
import 'package:sharely/features/transfer/widgets/incoming_offer_actions.dart';
import 'package:sharely/features/transfer/widgets/incoming_result_actions.dart';
import 'package:sharely/features/transfer/widgets/transfer_progress_bar.dart';
import 'package:sharely_core/sharely_core.dart';

/// Laptop notification for one incoming transfer, near the tray.
class IncomingTransferCard extends ConsumerWidget {
  const new({required this.view, super.key});

  final IncomingTransferView view;

  static const width = 380.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(incomingTransfersProvider.notifier);
    final transferId = view.transferId;
    return Container(
      width: width,
      padding: const EdgeInsets.all(SharelySpacing.lg + 2),
      decoration: BoxDecoration(
        color: SharelyColors.inkRaised,
        borderRadius: const BorderRadius.all(SharelyRadii.tile),
        border: Border.all(color: SharelyColors.inkBorderStrong),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: SharelySpacing.md,
        children: [
          _Header(view: view),
          if (view.stage == IncomingTransferStage.offered)
            _FileList(fileNames: view.fileNames),
          if (view.stage == IncomingTransferStage.receiving)
            TransferProgressBar(fraction: view.fraction),
          switch (view.stage) {
            IncomingTransferStage.offered => IncomingOfferActions(
              onAccept: () => controller.accept(transferId),
              onDecline: () => controller.decline(transferId),
            ),
            IncomingTransferStage.receiving => Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => controller.cancel(transferId),
                child: const Text('Cancel'),
              ),
            ),
            IncomingTransferStage.saved ||
            IncomingTransferStage.failed => IncomingResultActions(
              savedFiles: view.savedFiles,
              onDismiss: () => controller.dismiss(transferId),
            ),
          },
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const new({required this.view});

  final IncomingTransferView view;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final (icon, title, detail) = _describe();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: SharelySpacing.md,
      children: [
        Icon(icon, color: SharelyColors.accentOnInk, size: 22),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 2,
            children: [
              Text(
                title,
                style: textTheme.titleSmall?.copyWith(
                  color: SharelyColors.surface,
                ),
              ),
              Text(
                detail,
                style: textTheme.bodySmall?.copyWith(
                  color: SharelyColors.onInkMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  (IconData, String, String) _describe() {
    final summary =
        '${formatFileCount(view.fileNames.length)} · '
        '${formatByteCount(view.totalBytes)}';
    return switch (view.stage) {
      IncomingTransferStage.offered => (
        LucideIcons.download,
        '${view.senderName} wants to send',
        summary,
      ),
      IncomingTransferStage.receiving => (
        LucideIcons.download,
        'Receiving from ${view.senderName}',
        '${formatByteCount(view.bytesReceived)} of '
            '${formatByteCount(view.totalBytes)}',
      ),
      IncomingTransferStage.saved => (
        LucideIcons.circleCheck,
        'Saved ${formatFileCount(view.savedFiles.length)}',
        'In Downloads/Sharely',
      ),
      IncomingTransferStage.failed => (
        LucideIcons.circleAlert,
        'Transfer stopped',
        describeReceiveFailure(
          view.failure ?? TransferFailure.cancelled,
          view.senderName,
        ),
      ),
    };
  }
}

class _FileList extends StatelessWidget {
  const new({required this.fileNames});

  final List<String> fileNames;

  static const _maxShown = 3;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall
        ?.copyWith(color: SharelyColors.onInkSoft);
    final hidden = fileNames.length - _maxShown;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 2,
      children: [
        for (final name in fileNames.take(_maxShown))
          Text(
            name,
            style: style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        if (hidden > 0) Text('and $hidden more', style: style),
      ],
    );
  }
}
