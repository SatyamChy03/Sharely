import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sharely/design/tokens.dart';

/// Under the camera: what to do when the laptop isn't showing a code yet.
class NoCodeHintCard extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium
        ?.copyWith(color: SharelyColors.slate, height: 1.4);
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: SharelyColors.surface,
        borderRadius: BorderRadius.all(Radius.circular(18)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          spacing: SharelySpacing.md,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: SharelyColors.paper,
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
              child: const Icon(
                LucideIcons.laptop,
                size: 20,
                color: SharelyColors.ink,
              ),
            ),
            Expanded(
              child: Text.rich(
                TextSpan(
                  text: 'No code on your laptop? Open ',
                  children: [
                    TextSpan(
                      text: 'Sharely',
                      style: style?.copyWith(
                        color: SharelyColors.ink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const TextSpan(text: ' on it first.'),
                  ],
                ),
                style: style,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
