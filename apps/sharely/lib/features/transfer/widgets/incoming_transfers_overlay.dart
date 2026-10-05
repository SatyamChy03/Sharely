import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/features/transfer/state/incoming_transfers_controller.dart';
import 'package:sharely/features/transfer/widgets/incoming_transfer_card.dart';

/// Stacks incoming-transfer cards in the bottom-right corner, never blocking.
class IncomingTransfersOverlay extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final views = ref.watch(incomingTransfersProvider);
    return Positioned(
      right: SharelySpacing.xl,
      bottom: SharelySpacing.xl,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final view in views)
            Padding(
              key: ValueKey(view.transferId),
              padding: const EdgeInsets.only(top: SharelySpacing.md),
              child: IncomingTransferCard(view: view)
                  .animate()
                  .fadeIn(duration: SharelyMotion.medium)
                  .slideY(begin: 0.2, curve: SharelyMotion.emphasized),
            ),
        ],
      ),
    );
  }
}
