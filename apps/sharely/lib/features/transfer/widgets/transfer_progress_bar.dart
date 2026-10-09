import 'package:flutter/material.dart';
import 'package:sharely/design/tokens.dart';

/// Rounded progress bar for transfers, for light or dark surfaces.
class TransferProgressBar extends StatelessWidget {
  const new({required this.fraction, super.key, this.isOnDark = true});

  final double fraction;
  final bool isOnDark;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.all(SharelyRadii.chip),
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: fraction.clamp(0, 1)),
        duration: SharelyMotion.fast,
        builder: (context, value, _) => LinearProgressIndicator(
          value: value,
          minHeight: 8,
          backgroundColor: isOnDark
              ? SharelyColors.inkBorderStrong
              : SharelyColors.mist,
          color: isOnDark ? SharelyColors.accentOnInk : SharelyColors.accent,
        ),
      ),
    );
  }
}
