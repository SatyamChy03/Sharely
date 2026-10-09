import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/design/typography.dart';
import 'package:sharely/design/widgets/icon_tile.dart';
import 'package:sharely/design/widgets/pulse_rings.dart';
import 'package:sharely/design/widgets/sharely_button.dart';
import 'package:sharely/design/widgets/status_badge.dart';
import 'package:sharely/design/widgets/surface_card.dart';
import 'package:sharely/features/laptop/open_folder.dart';
import 'package:sharely/features/laptop/widgets/activity_table_row.dart';
import 'package:sharely/features/laptop/widgets/laptop_page.dart';
import 'package:sharely/features/laptop/widgets/page_heading.dart';
import 'package:sharely/features/laptop/widgets/receiving_card.dart';
import 'package:sharely/features/transfer/state/activity_filter.dart';
import 'package:sharely/features/transfer/state/incoming_transfer_view.dart';
import 'package:sharely/features/transfer/state/incoming_transfers_controller.dart';
import 'package:sharely/features/transfer/state/recent_transfers.dart';
import 'package:sharely/features/transfer/state/save_folder.dart';

/// Laptop Receive (D11): where files land, what is arriving, what arrived.
class LaptopReceiveView extends ConsumerWidget {
  const new({required this.connectedCount, super.key});

  /// Paired phones with a live connection right now.
  final int connectedCount;

  static const _receivedShown = 12;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final receiving = [
      for (final view in ref.watch(incomingTransfersProvider))
        if (view.stage == IncomingTransferStage.receiving) view,
    ];
    final received = ActivityFilter.received.apply(
      ref.watch(recentTransfersProvider),
    );
    final folder = ref.watch(laptopSaveFolderProvider).value?.path;
    final incoming = ref.read(incomingTransfersProvider.notifier);
    return LaptopPage(
      children: [
        const PageHeading(
          title: 'Receive',
          subtitle: 'Files sent from your devices land here.',
        ),
        _ReadyCard(connectedCount: connectedCount, folderPath: folder),
        for (final view in receiving)
          ReceivingCard(
            view: view,
            onCancel: () => incoming.cancel(view.transferId),
          ),
        SurfaceCard(
          padding: const EdgeInsets.all(SharelySpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                child: Text(
                  'Received',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              if (received.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Text(
                    'Files your phone sends to this laptop are listed here.',
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: SharelyColors.textSecondary),
                  ),
                ),
              for (final transfer in received.take(_receivedShown))
                ActivityTableRow(transfer: transfer),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReadyCard extends StatelessWidget {
  const new({required this.connectedCount, required this.folderPath});

  final int connectedCount;
  final String? folderPath;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isReady = connectedCount > 0;
    const tile = IconTile(
      icon: LucideIcons.arrowDownToLine,
      size: 56,
      radius: SharelyRadii.tile,
    );
    final path = folderPath;
    return SurfaceCard(
      padding: const EdgeInsets.all(SharelySpacing.page),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: SharelySpacing.page,
        runSpacing: SharelySpacing.page,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            spacing: SharelySpacing.lg,
            children: [
              ExcludeSemantics(
                child: isReady
                    ? const PulseRings(
                        size: 56,
                        radius: SharelyRadii.tile,
                        child: tile,
                      )
                    : tile,
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                spacing: 4,
                children: [
                  Text(
                    isReady ? 'Ready to receive' : 'Waiting for your phone',
                    style: textTheme.titleLarge,
                  ),
                  StatusBadge(
                    label: switch (connectedCount) {
                      0 => 'No paired device is connected',
                      1 => '1 paired device connected',
                      _ => '$connectedCount paired devices connected',
                    },
                    tone: isReady ? StatusTone.connected : StatusTone.offline,
                    isPlain: true,
                  ),
                ],
              ),
            ],
          ),
          if (path != null) _SaveFolder(path: path),
        ],
      ),
    );
  }
}

class _SaveFolder extends StatelessWidget {
  const new({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 10,
      children: [
        Text(
          'Save to',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: SharelyColors.textSecondary),
        ),
        Flexible(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 340),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: SharelyColors.background,
              borderRadius: const BorderRadius.all(SharelyRadii.row),
              border: Border.all(color: SharelyColors.line),
            ),
            child: Text(
              path,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: sharelyMonoStyle(size: 12, color: SharelyColors.text),
            ),
          ),
        ),
        SharelyButton(
          label: 'Open folder',
          variant: SharelyButtonVariant.secondary,
          height: SharelySizes.buttonSmall,
          isExpanded: false,
          onPressed: () => unawaited(openFolder(path)),
        ),
      ],
    );
  }
}
