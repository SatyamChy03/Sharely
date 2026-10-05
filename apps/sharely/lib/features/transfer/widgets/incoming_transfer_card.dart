import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/design/typography.dart';
import 'package:sharely/design/widgets/sharely_logo.dart';
import 'package:sharely/features/transfer/state/incoming_transfer_view.dart';
import 'package:sharely/features/transfer/state/incoming_transfers_controller.dart';
import 'package:sharely/features/transfer/transfer_formatting.dart';
import 'package:sharely/features/transfer/widgets/incoming_file_chips.dart';
import 'package:sharely/features/transfer/widgets/incoming_offer_actions.dart';
import 'package:sharely/features/transfer/widgets/incoming_result_actions.dart';
import 'package:sharely/features/transfer/widgets/transfer_progress_bar.dart';
import 'package:sharely_core/sharely_core.dart';

/// Laptop notification for one incoming transfer, near the tray.
class IncomingTransferCard extends ConsumerWidget {
  const new({required this.view, super.key});

  final IncomingTransferView view;

  static const maxWidth = 420.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(incomingTransfersProvider.notifier);
    final transferId = view.transferId;
    return Semantics(
      container: true,
      liveRegion: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: maxWidth),
        // Material, not a decorated box, so the checkbox's ink shows.
        child: Material(
          color: SharelyColors.ink,
          elevation: 12,
          shadowColor: SharelyColors.ink.withValues(alpha: 0.4),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(26)),
            // Keeps the card distinct on the dark get-started screen.
            side: BorderSide(color: SharelyColors.inkBorderStrong),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 16,
              children: [
                const _AppHeader(),
                _Summary(view: view),
                if (view.stage == IncomingTransferStage.offered)
                  IncomingFileChips(fileNames: view.fileNames),
                if (view.stage == IncomingTransferStage.receiving)
                  TransferProgressBar(fraction: view.fraction),
                switch (view.stage) {
                  IncomingTransferStage.offered => IncomingOfferActions(
                    onAccept: (always) =>
                        controller.accept(transferId, alwaysFromSender: always),
                    onDecline: () => controller.decline(transferId),
                  ),
                  IncomingTransferStage.receiving => NotificationButton(
                    label: 'Cancel',
                    onPressed: () => controller.cancel(transferId),
                  ),
                  IncomingTransferStage.saved ||
                  IncomingTransferStage.failed => IncomingResultActions(
                    savedFiles: view.savedFiles,
                    onDismiss: () => controller.dismiss(transferId),
                  ),
                },
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AppHeader extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      spacing: 10,
      children: [
        const SharelyLogoMark(size: 22),
        Expanded(
          child: Text(
            'Sharely',
            style: textTheme.labelMedium?.copyWith(
              color: SharelyColors.surface,
              fontSize: 13,
            ),
          ),
        ),
        Text(
          'now',
          style: textTheme.bodySmall?.copyWith(color: SharelyColors.onInkMuted),
        ),
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  const new({required this.view});

  final IncomingTransferView view;

  @override
  Widget build(BuildContext context) {
    final (title, detail, isDetailMono) = switch (view.stage) {
      IncomingTransferStage.offered => (
        '${view.senderName} is sending '
            '${formatFileCount(view.fileNames.length)}',
        formatByteCount(view.totalBytes),
        true,
      ),
      IncomingTransferStage.receiving => (
        'Receiving from ${view.senderName}',
        '${formatByteCount(view.bytesReceived)} of '
            '${formatByteCount(view.totalBytes)}',
        true,
      ),
      IncomingTransferStage.saved => (
        'Saved ${formatFileCount(view.savedFiles.length)}',
        'In Downloads/Sharely',
        false,
      ),
      IncomingTransferStage.failed => (
        'Transfer stopped',
        describeReceiveFailure(
          view.failure ?? TransferFailure.cancelled,
          view.senderName,
        ),
        false,
      ),
    };
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 4,
      children: [
        Text(
          title,
          style: textTheme.titleLarge?.copyWith(
            color: SharelyColors.surface,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        Text(
          detail,
          style: isDetailMono
              ? sharelyMonoStyle(size: 13, color: SharelyColors.onInkQuiet)
              : textTheme.bodyMedium?.copyWith(color: SharelyColors.onInkQuiet),
        ),
      ],
    );
  }
}
