import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/design/typography.dart';
import 'package:sharely/design/widgets/icon_tile.dart';
import 'package:sharely/design/widgets/pulse_rings.dart';
import 'package:sharely/design/widgets/sharely_button.dart';
import 'package:sharely/design/widgets/sheet_grabber.dart';
import 'package:sharely/features/transfer/state/incoming_transfer_view.dart';
import 'package:sharely/features/transfer/state/laptop_offers_controller.dart';
import 'package:sharely/features/transfer/transfer_formatting.dart';
import 'package:sharely/features/transfer/widgets/laptop_offer_decision.dart';
import 'package:sharely/features/transfer/widgets/offer_file_rows.dart';
import 'package:sharely/features/transfer/widgets/transfer_progress_bar.dart';
import 'package:sharely_core/sharely_core.dart';

/// Phone bottom sheet for one transfer arriving from the laptop (M11).
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
          borderRadius: BorderRadius.vertical(top: SharelyRadii.card),
          side: BorderSide(color: SharelyColors.lineStrong),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 18,
              children: [
                const Center(child: SheetGrabber()),
                _Header(view: view),
                ..._buildStage(controller, transferId),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildStage(LaptopOffersController controller, String id) {
    return switch (view.stage) {
      IncomingTransferStage.offered => [
        OfferFileRows(
          fileNames: view.fileNames,
          fileSizes: view.fileSizes,
          totalBytes: view.totalBytes,
        ),
        LaptopOfferDecision(
          onAccept: (always) => controller.accept(id, alwaysFromLaptop: always),
          onDecline: () => controller.decline(id),
        ),
      ],
      IncomingTransferStage.receiving => [
        _ReceivingProgress(view: view),
        SharelyButton(
          label: 'Cancel',
          variant: SharelyButtonVariant.danger,
          onPressed: () => controller.cancel(id),
        ),
      ],
      IncomingTransferStage.saved || IncomingTransferStage.failed => [
        SharelyButton(label: 'Done', onPressed: () => controller.dismiss(id)),
      ],
    };
  }
}

class _Header extends StatelessWidget {
  const new({required this.view});

  final IncomingTransferView view;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final (icon, color) = switch (view.stage) {
      IncomingTransferStage.saved => (LucideIcons.check, SharelyColors.success),
      IncomingTransferStage.failed => (
        LucideIcons.circleAlert,
        SharelyColors.dangerText,
      ),
      _ => (LucideIcons.laptop, SharelyColors.primary),
    };
    final tile = IconTile(
      icon: icon,
      size: 64,
      radius: SharelyRadii.zone,
      color: color,
    );
    return Column(
      spacing: SharelySpacing.sm,
      children: [
        ExcludeSemantics(
          child: view.stage == IncomingTransferStage.offered
              ? PulseRings(size: 64, child: tile)
              : tile,
        ),
        Text(
          _title(),
          textAlign: TextAlign.center,
          style: textTheme.headlineSmall,
        ),
        Text(
          _detail(),
          textAlign: TextAlign.center,
          style: textTheme.bodyMedium?.copyWith(
            color: SharelyColors.textSecondary,
          ),
        ),
      ],
    );
  }

  String _title() => switch (view.stage) {
    IncomingTransferStage.offered ||
    IncomingTransferStage.receiving => view.senderName,
    IncomingTransferStage.saved =>
      'Saved ${formatFileCount(view.savedFiles.length)}',
    IncomingTransferStage.failed => 'Transfer stopped',
  };

  String _detail() => switch (view.stage) {
    IncomingTransferStage.offered =>
      'wants to send ${formatFileCount(view.fileNames.length)}',
    IncomingTransferStage.receiving when view.isReconnecting =>
      'Reconnecting. It continues by itself.',
    IncomingTransferStage.receiving =>
      'is sending ${formatFileCount(view.fileNames.length)}',
    IncomingTransferStage.saved => 'Saved in Downloads/Sharely',
    IncomingTransferStage.failed => describeReceiveFailure(
      view.failure ?? TransferFailure.cancelled,
      view.senderName,
    ),
  };
}

class _ReceivingProgress extends StatelessWidget {
  const new({required this.view});

  final IncomingTransferView view;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: SharelySpacing.sm,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${formatByteCount(view.bytesReceived)} of '
              '${formatByteCount(view.totalBytes)}',
              style: sharelyMonoStyle(
                size: 12,
                color: SharelyColors.textSecondary,
              ),
            ),
            Text(
              '${(view.fraction * 100).floor()}%',
              style: sharelyMonoStyle(
                size: 15,
                color: view.isReconnecting
                    ? SharelyColors.textSecondary
                    : SharelyColors.primary,
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
    );
  }
}
