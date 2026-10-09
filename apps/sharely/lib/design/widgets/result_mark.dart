import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sharely/design/tokens.dart';

/// The big tick shown when pairing or a transfer finishes.
class ResultMark extends StatelessWidget {
  const new({
    super.key,
    this.color = SharelyColors.primary,
    this.size = 120,
    this.icon = LucideIcons.check,
  });

  final Color color;
  final double size;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final mark = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Container(
        width: size * 0.64,
        height: size * 0.64,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        child: Icon(icon, size: size * 0.32, color: SharelyColors.onPrimary),
      ),
    );
    if (MediaQuery.disableAnimationsOf(context)) return mark;
    return mark
        .animate()
        .scaleXY(
          begin: 0.6,
          end: 1,
          duration: SharelyMotion.slow,
          curve: Curves.easeOutBack,
        )
        .fadeIn(duration: SharelyMotion.medium);
  }
}
