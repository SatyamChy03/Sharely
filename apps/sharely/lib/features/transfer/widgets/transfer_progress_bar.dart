import 'package:flutter/material.dart';
import 'package:sharely/design/tokens.dart';

/// Rounded progress bar for transfers; grey while the transfer is stalled.
class TransferProgressBar extends StatelessWidget {
  const new({
    required this.fraction,
    super.key,
    this.height = 4,
    this.isStalled = false,
  });

  final double fraction;
  final double height;
  final bool isStalled;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.all(SharelyRadii.pill),
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: fraction.clamp(0, 1)),
        duration: SharelyMotion.fast,
        builder: (context, value, _) => LinearProgressIndicator(
          value: value,
          minHeight: height,
          backgroundColor: SharelyColors.elevated,
          color: isStalled ? SharelyColors.stalled : SharelyColors.primary,
        ),
      ),
    );
  }
}
