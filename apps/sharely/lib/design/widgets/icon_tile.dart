import 'package:flutter/material.dart';
import 'package:sharely/design/tokens.dart';

/// An icon on a rounded square, used for devices and list leading marks.
class IconTile extends StatelessWidget {
  const new({
    required this.icon,
    super.key,
    this.size = 44,
    this.radius = SharelyRadii.button,
    this.color = SharelyColors.primary,
    this.background = SharelyColors.elevated,
    this.borderColor,
  });

  final IconData icon;
  final double size;
  final Radius radius;
  final Color color;
  final Color background;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final border = borderColor;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.all(radius),
        border: border == null ? null : Border.all(color: border),
      ),
      child: Icon(icon, size: size * 0.48, color: color),
    );
  }
}
