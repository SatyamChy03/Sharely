import 'package:flutter/material.dart';
import 'package:sharely/design/tokens.dart';

/// A laptop page's title with an optional line under it and an action.
class PageHeading extends StatelessWidget {
  const new({
    required this.title,
    super.key,
    this.overline,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? overline;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final secondary = textTheme.bodyMedium?.copyWith(
      color: SharelyColors.textSecondary,
    );
    final above = overline;
    final below = subtitle;
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.end,
      spacing: SharelySpacing.lg,
      runSpacing: SharelySpacing.lg,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          spacing: 6,
          children: [
            if (above != null)
              Text(
                above,
                style: textTheme.labelMedium?.copyWith(
                  color: SharelyColors.textSecondary,
                ),
              ),
            Text(title, style: textTheme.headlineLarge),
            if (below != null) Text(below, style: secondary),
          ],
        ),
        ?trailing,
      ],
    );
  }
}
