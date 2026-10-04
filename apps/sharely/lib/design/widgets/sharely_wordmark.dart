import 'package:flutter/material.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/design/widgets/sharely_logo.dart';

/// Mark plus the lowercase "sharely" wordmark.
class SharelyWordmark extends StatelessWidget {
  const new({
    super.key,
    this.markSize = 28,
    this.textColor = SharelyColors.surface,
  });

  final double markSize;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.headlineMedium?.copyWith(
      fontSize: markSize * 0.8,
      letterSpacing: -1,
      color: textColor,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(child: SharelyLogoMark(size: markSize)),
        SizedBox(width: markSize * 0.36),
        Text('sharely', style: textStyle),
      ],
    );
  }
}
