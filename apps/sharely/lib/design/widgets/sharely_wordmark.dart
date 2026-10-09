import 'package:flutter/material.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/design/widgets/sharely_logo.dart';

/// Mark plus the lowercase "sharely" wordmark.
class SharelyWordmark extends StatelessWidget {
  const new({super.key, this.markSize = 28});

  final double markSize;

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.headlineMedium?.copyWith(
      fontSize: markSize * 0.75,
      letterSpacing: -0.8,
      height: 1,
      color: SharelyColors.text,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(child: SharelyLogoMark(size: markSize)),
        const SizedBox(width: 10),
        Text('sharely', style: textStyle),
      ],
    );
  }
}
