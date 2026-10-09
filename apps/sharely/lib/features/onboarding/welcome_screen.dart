import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sharely/app/routes.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/design/widgets/sharely_button.dart';
import 'package:sharely/design/widgets/sharely_wordmark.dart';
import 'package:sharely/features/onboarding/widgets/welcome_illustration.dart';

/// First screen for new users (M01 of the v3 design).
class WelcomeScreen extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return const AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(24, 28, 24, 32),
            child: _WelcomeContent(),
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
        // The picture absorbs spare height and shrinks first on short phones.
        const Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: SharelySpacing.md),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: WelcomeIllustration(),
              ),
            ),
          ),
        ),
        ...[
              const _Headline(),
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Text(
                  'Pair your phone and laptop once. Then send photos, '
                  'files and links in a tap.',
                  style: textTheme.bodyLarge?.copyWith(
                    height: 1.5,
                    color: SharelyColors.textSecondary,
                  ),
                ),
              ),
            ]
            .animate(interval: 70.ms)
            .fadeIn(duration: SharelyMotion.slow)
            .slideY(begin: 0.06, curve: SharelyMotion.emphasized),
        const Gap(SharelySpacing.xxl),
        SharelyButton(
          label: 'Get started',
          trailingIcon: LucideIcons.arrowRight,
          onPressed: () => context.push(AppRoutes.scan),
        ),
        const Gap(14),
        const _DirectTransferNote(),
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
        text: 'Transfer anything between your devices. ',
        children: [
          TextSpan(
            text: 'Instantly.',
            style: TextStyle(color: SharelyColors.primary),
          ),
        ],
      ),
      style: Theme.of(context).textTheme.displayMedium?.copyWith(height: 1.08),
    );
  }
}

class _DirectTransferNote extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      spacing: SharelySpacing.sm,
      children: [
        const Icon(
          LucideIcons.shieldCheck,
          size: 16,
          color: SharelyColors.primary,
        ),
        Flexible(
          child: Text(
            'Files go directly between your devices',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: SharelyColors.textSecondary),
          ),
        ),
      ],
    );
  }
}
