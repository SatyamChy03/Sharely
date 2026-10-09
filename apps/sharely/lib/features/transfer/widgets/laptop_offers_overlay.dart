import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/features/transfer/state/laptop_offers_controller.dart';
import 'package:sharely/features/transfer/widgets/laptop_offer_sheet.dart';

/// Shows the oldest transfer from the laptop as a sheet over the phone's
/// Home; later ones wait their turn behind it.
class LaptopOffersOverlay extends ConsumerWidget {
  const new({super.key});

  static const _maxSheetWidth = 480.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(laptopOffersProvider).firstOrNull;
    if (view == null) return const SizedBox.shrink();
    return Stack(
      children: [
        ModalBarrier(
          dismissible: false,
          color: SharelyColors.ink.withValues(alpha: 0.55),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(10),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxSheetWidth),
              child:
                  LaptopOfferSheet(key: ValueKey(view.transferId), view: view)
                      .animate()
                      .fadeIn(duration: SharelyMotion.medium)
                      .slideY(begin: 0.15, curve: SharelyMotion.emphasized),
            ),
          ),
        ),
      ],
    );
  }
}
