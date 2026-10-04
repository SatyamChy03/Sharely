import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sharely/design/tokens.dart';

/// Pairing step 2 of 3. Camera scanning lands with the pairing feature.
class ScanScreen extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(SharelySpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton.filledTonal(
                tooltip: 'Back',
                onPressed: () => context.pop(),
                style: IconButton.styleFrom(
                  backgroundColor: SharelyColors.surface,
                  foregroundColor: SharelyColors.ink,
                ),
                icon: const Icon(LucideIcons.chevronLeft),
              ),
              const Gap(SharelySpacing.xl),
              Text(
                'Scan the code on your laptop',
                style: textTheme.headlineLarge,
              ),
              const Gap(SharelySpacing.sm),
              Text(
                'It pairs once. After that, your devices find each other '
                'on their own.',
                style: textTheme.bodyLarge?.copyWith(
                  color: SharelyColors.slate,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
