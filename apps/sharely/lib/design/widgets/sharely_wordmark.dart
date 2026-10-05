import 'package:flutter/material.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/design/widgets/sharely_logo.dart';

/// Mark plus the lowercase "sharely" wordmark, for dark or light screens.
class SharelyWordmark extends StatelessWidget {
  const new({super.key, this.markSize = 28, this.isOnDark = true});

  final double markSize;
  final bool isOnDark;

  @override
  Widget build(BuildContext context) {
    final textColor = isOnDark ? SharelyColors.surface : SharelyColors.ink;
    final textStyle = Theme.of(context).textTheme.headlineMedium?.copyWith(
      fontSize: markSize * 0.8,
      letterSpacing: -1,
      color: textColor,
    );
    final mark = isOnDark
        ? SharelyLogoMark(size: markSize)
        : SharelyLogoMark(
            size: markSize,
            pathColor: SharelyColors.ink,
            startDotColor: SharelyColors.ink,
            endDotColor: SharelyColors.accent,
          );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(child: mark),
        SizedBox(width: markSize * 0.36),
        Text('sharely', style: textStyle),
      ],
    );
  }
}
