import 'package:flutter/material.dart';
import 'package:sharely/design/tokens.dart';

/// A small capital label above a group, such as "TODAY" or "TRANSFER".
class SectionLabel extends StatelessWidget {
  const new(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
        color: SharelyColors.textSecondary,
      ),
    );
  }
}
