import 'package:flutter/material.dart';
import 'package:sharely/design/tokens.dart';

/// A 44 px icon-only button, for back, close and row menus.
class IconSquareButton extends StatelessWidget {
  const new({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    super.key,
    this.size = SharelySizes.minTouchTarget,
    this.background = SharelyColors.surface,
    this.color = SharelyColors.text,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final double size;
  final Color background;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        icon: Icon(icon, size: 20),
        style: IconButton.styleFrom(
          backgroundColor: background,
          foregroundColor: color,
          hoverColor: SharelyColors.secondaryHover,
          padding: EdgeInsets.zero,
          minimumSize: Size.square(size),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(SharelyRadii.button),
          ),
        ),
      ),
    );
  }
}
