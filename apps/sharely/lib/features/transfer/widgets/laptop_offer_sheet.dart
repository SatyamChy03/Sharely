import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/design/typography.dart';
import 'package:sharely/features/transfer/state/incoming_transfer_view.dart';
import 'package:sharely/features/transfer/state/laptop_offers_controller.dart';
import 'package:sharely/features/transfer/transfer_formatting.dart';
import 'package:sharely/features/transfer/widgets/laptop_offer_decision.dart';
import 'package:sharely/features/transfer/widgets/offer_file_rows.dart';
import 'package:sharely/features/transfer/widgets/transfer_progress_bar.dart';
import 'package:sharely_core/sharely_core.dart';

/// Phone bottom sheet for one transfer arriving from the laptop.
class LaptopOfferSheet extends ConsumerWidget {
  const new({required this.view, super.key});

  final IncomingTransferView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(laptopOffersProvider.notifier);
    final transferId = view.transferId;
    return Semantics(
      container: true,
      liveRegion: true,
      // Material, not a decorated box, so the checkbox's ink shows.
      child: Material(
        color: SharelyColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(34)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 18,
            children: [
              const _GrabHandle(),
              _Header(view: view),
              ...switch (view.stage) {
                IncomingTransferStage.offered => [
                  OfferFileRows(
                    fileNames: view.fileNames,
                    fileSizes: view.fileSizes,
                  ),
                  LaptopOfferDecision(
                    onAccept: (always) =>
                        controller.accept(transferId, alwaysFromLaptop: always),
                    onDecline: () => controller.decline(transferId),
                  ),
                ],
                IncomingTransferStage.receiving => [
                  TransferProgressBar(fraction: view.fraction, isOnDark: false),
                  SheetButton(
                    label: 'Cancel',
                    onPressed: () => controller.cancel(transferId),
                  ),
                ],
                IncomingTransferStage.saved || IncomingTransferStage.failed => [
                  SheetButton(
                    label: 'Done',
                    isPrimary: true,
                    onPressed: () => controller.dismiss(transferId),
                  ),
                ],
              },
            ],
          ),
        ),
      ),
    );
  }
}

class _GrabHandle extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 5,
        decoration: const BoxDecoration(
          color: SharelyColors.mist,
          borderRadius: BorderRadius.all(SharelyRadii.chip),
        ),
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
    final (label, title, monoDetail) = _describe();
    return Row(
      spacing: 14,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: const BoxDecoration(
            color: SharelyColors.ink,
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
          child: const Icon(
            LucideIcons.laptop,
            size: 26,
            color: SharelyColors.surface,
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 2,
            children: [
              Text(
                label,
                style: textTheme.bodySmall?.copyWith(
                  color: SharelyColors.slate,
                ),
              ),
              Text.rich(
                TextSpan(
                  text: monoDetail == null ? title : '$title · ',
                  children: [
                    if (monoDetail != null)
                      TextSpan(
                        text: monoDetail,
                        style: sharelyMonoStyle(
                          size: 20,
                          color: SharelyColors.ink,
                        ),
                      ),
                  ],
                ),
                style: textTheme.headlineMedium?.copyWith(
                  fontSize: 22,
                  letterSpacing: -0.6,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  (String label, String title, String? monoDetail) _describe() {
    final sender = view.senderName;
    return switch (view.stage) {
      IncomingTransferStage.offered => (
        '$sender is sending',
        formatFileCount(view.fileNames.length),
        formatByteCount(view.totalBytes),
      ),
      IncomingTransferStage.receiving when view.isReconnecting => (
        'Reconnecting to $sender. It continues by itself.',
        '${(view.fraction * 100).floor()}%',
        '${formatByteCount(view.bytesReceived)} of '
            '${formatByteCount(view.totalBytes)}',
      ),
      IncomingTransferStage.receiving => (
        'Receiving from $sender',
        '${(view.fraction * 100).floor()}%',
        '${formatByteCount(view.bytesReceived)} of '
            '${formatByteCount(view.totalBytes)}',
      ),
      IncomingTransferStage.saved => (
        'Saved in Downloads/Sharely',
        'Saved ${formatFileCount(view.savedFiles.length)}',
        null,
      ),
      IncomingTransferStage.failed => (
        describeReceiveFailure(
          view.failure ?? TransferFailure.cancelled,
          sender,
        ),
        'Transfer stopped',
        null,
      ),
    };
  }
}
