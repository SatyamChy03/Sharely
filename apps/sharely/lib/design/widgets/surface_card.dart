import 'package:flutter/material.dart';
import 'package:sharely/design/tokens.dart';

/// A card: one tone above the canvas with a hairline border, no shadow.
class SurfaceCard extends StatelessWidget {
  const new({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(SharelySpacing.lg),
    this.radius = SharelyRadii.card,
    this.color = SharelyColors.surface,
    this.borderColor = SharelyColors.line,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Radius radius;
  final Color color;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.all(radius),
        border: Border.all(color: borderColor),
      ),
      child: child,
    );
  }
}
