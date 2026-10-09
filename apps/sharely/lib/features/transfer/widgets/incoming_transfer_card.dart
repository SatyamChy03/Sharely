import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/design/typography.dart';
import 'package:sharely/design/widgets/icon_tile.dart';
import 'package:sharely/design/widgets/sharely_button.dart';
import 'package:sharely/features/transfer/state/incoming_transfer_view.dart';
import 'package:sharely/features/transfer/state/incoming_transfers_controller.dart';
import 'package:sharely/features/transfer/transfer_formatting.dart';
import 'package:sharely/features/transfer/widgets/incoming_offer_actions.dart';
import 'package:sharely/features/transfer/widgets/incoming_result_actions.dart';
import 'package:sharely/features/transfer/widgets/offer_file_rows.dart';
import 'package:sharely/features/transfer/widgets/transfer_progress_bar.dart';
import 'package:sharely_core/sharely_core.dart';

/// Laptop notification for one incoming transfer, near the tray (D12).
class IncomingTransferCard extends ConsumerWidget {
  const new({required this.view, super.key});

  final IncomingTransferView view;

  static const maxWidth = 380.0;

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
          color: SharelyColors.elevated,
          elevation: 6,
          shadowColor: SharelyColors.shadow,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(SharelyRadii.tile),
            side: BorderSide(color: SharelyColors.lineHover),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: SharelySpacing.md,
              children: [
                _AppHeader(
                  onClose: view.stage == IncomingTransferStage.offered
                      ? null
                      : () => controller.dismiss(transferId),
                ),
                _Summary(view: view),
                if (view.stage == IncomingTransferStage.offered)
                  OfferFileRows(
                    fileNames: view.fileNames,
                    fileSizes: view.fileSizes,
                    totalBytes: view.totalBytes,
                    isCompact: true,
                  ),
                if (view.stage == IncomingTransferStage.receiving)
                  TransferProgressBar(
                    fraction: view.fraction,
                    height: 6,
                    isStalled: view.isReconnecting,
                  ),
                _buildActions(controller),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActions(IncomingTransfersController controller) {
    final transferId = view.transferId;
    return switch (view.stage) {
      IncomingTransferStage.offered => IncomingOfferActions(
        onAccept: (always) =>
            controller.accept(transferId, alwaysFromSender: always),
        onDecline: () => controller.decline(transferId),
      ),
      IncomingTransferStage.receiving => SharelyButton(
        label: 'Cancel',
        variant: SharelyButtonVariant.danger,
        height: 40,
        onPressed: () => controller.cancel(transferId),
      ),
      IncomingTransferStage.saved ||
      IncomingTransferStage.failed => IncomingResultActions(
        savedFiles: view.savedFiles,
        onDismiss: () => controller.dismiss(transferId),
      ),
    };
  }
}

class _AppHeader extends StatelessWidget {
  const new({required this.onClose});

  /// Null while the offer still needs an answer.
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Sharely · now',
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: SharelyColors.textSecondary),
          ),
        ),
        if (onClose != null)
          SizedBox.square(
            dimension: 28,
            child: IconButton(
              onPressed: onClose,
              tooltip: 'Close',
              padding: EdgeInsets.zero,
              icon: const Icon(
                LucideIcons.x,
                size: 14,
                color: SharelyColors.textSecondary,
              ),
            ),
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
    final (title, detail, isDetailMono) = _describe();
    final textTheme = Theme.of(context).textTheme;
    final (icon, color) = switch (view.stage) {
      IncomingTransferStage.saved => (LucideIcons.check, SharelyColors.success),
      IncomingTransferStage.failed => (
        LucideIcons.circleAlert,
        SharelyColors.dangerText,
      ),
      _ => (LucideIcons.smartphone, SharelyColors.primary),
    };
    return Row(
      spacing: SharelySpacing.md,
      children: [
        IconTile(
          icon: icon,
          size: 40,
          color: color,
          background: SharelyColors.background,
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 1,
            children: [
              Text(title, style: textTheme.titleSmall),
              Text(
                detail,
                style: isDetailMono
                    ? sharelyMonoStyle(
                        size: 12,
                        color: SharelyColors.textSecondary,
                      )
                    : textTheme.bodySmall?.copyWith(
                        color: SharelyColors.textSecondary,
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  (String title, String detail, bool isDetailMono) _describe() {
    return switch (view.stage) {
      IncomingTransferStage.offered => (
        view.senderName,
        'wants to send ${formatFileCount(view.fileNames.length)}',
        false,
      ),
      IncomingTransferStage.receiving when view.isReconnecting => (
        'Waiting for ${view.senderName} to reconnect',
        'It continues by itself when the Wi-Fi is back.',
        false,
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
  }
}
