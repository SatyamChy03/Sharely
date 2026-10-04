import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sharely/app/routes.dart';
import 'package:sharely/design/theme.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/design/widgets/sharely_button.dart';
import 'package:sharely/design/widgets/sharely_wordmark.dart';
import 'package:sharely/features/onboarding/widgets/transfer_orbit.dart';

/// First screen for new users (Get started, step 1 of the v2 design).
class WelcomeScreen extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: SharelyTheme.dark(),
      child: const AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          body: SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: _WelcomeContent(),
            ),
          ),
        ),
      ),
    );
  }
}

class _WelcomeContent extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SharelyWordmark(),
        // The orbit absorbs spare height and shrinks first on short screens.
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: SharelySpacing.lg),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300),
                child: const TransferOrbit(),
              ),
            ),
          ),
        ),
        ...[
              const _Headline(),
              Padding(
                padding: const EdgeInsets.only(top: SharelySpacing.md),
                child: Text(
                  'Photos, files, links and your clipboard, '
                  'straight over your Wi-Fi.',
                  style: textTheme.bodyLarge?.copyWith(
                    color: SharelyColors.onInkSoft,
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: SharelySpacing.xl),
                child: _TrustChips(),
              ),
            ]
            .animate(interval: 70.ms)
            .fadeIn(duration: SharelyMotion.slow)
            .slideY(begin: 0.06, curve: SharelyMotion.emphasized),
        const Gap(SharelySpacing.xl),
        SharelyButton(
          label: 'Get started',
          trailingIcon: LucideIcons.arrowRight,
          onPressed: () => context.push(AppRoutes.scan),
        ),
        const Gap(SharelySpacing.md),
        Center(
          child: Text(
            'Takes about 2 minutes',
            style: textTheme.bodyMedium?.copyWith(
              color: SharelyColors.onInkMuted,
            ),
          ),
        ),
      ],
    );
  }
}

class _Headline extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      const TextSpan(
        text: 'Send anything to your laptop. ',
        children: [
          TextSpan(
            text: 'Instantly.',
            style: TextStyle(color: SharelyColors.accentOnInk),
          ),
        ],
      ),
      style: Theme.of(context).textTheme.displayMedium,
    );
  }
}

class _TrustChips extends StatelessWidget {
  const new();

  static const _promises = ['No ads', 'No account', 'No cloud'];

  @override
  Widget build(BuildContext context) {
    final chipStyle = Theme.of(context).textTheme.labelMedium
        ?.copyWith(fontSize: 13, color: SharelyColors.onInkSoft);
    return Wrap(
      spacing: SharelySpacing.sm,
      runSpacing: SharelySpacing.sm,
      children: [
        for (final promise in _promises)
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.all(SharelyRadii.chip),
              border: Border.all(color: SharelyColors.inkBorderStrong),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              child: Text(promise, style: chipStyle),
            ),
          ),
      ],
    );
  }
}
