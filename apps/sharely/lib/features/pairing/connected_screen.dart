import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:sharely/app/routes.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/design/widgets/sharely_button.dart';
import 'package:sharely/features/pairing/state/paired_devices.dart';
import 'package:sharely/features/pairing/widgets/connected_illustration.dart';
import 'package:sharely/features/pairing/widgets/paired_device_card.dart';
import 'package:sharely/features/pairing/widgets/step_progress.dart';

/// Get started step 3 of 3: the phone now trusts the laptop.
class ConnectedScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devices = ref.watch(pairedDevicesProvider).value ?? const [];
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  height: 48,
                  child: StepProgress(currentStep: 3),
                ),
              ),
              const Gap(SharelySpacing.lg),
              const Flexible(child: ConnectedIllustration()),
              const Gap(SharelySpacing.xl),
              ...[
                    Text("You're connected.", style: textTheme.headlineLarge),
                    Padding(
                      padding: const EdgeInsets.only(top: SharelySpacing.sm),
                      child: Text(
                        "Your phone and laptop are paired. Let's send "
                        'something to make sure it works.',
                        style: textTheme.bodyLarge?.copyWith(
                          color: SharelyColors.slate,
                        ),
                      ),
                    ),
                    if (devices.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: SharelySpacing.xl),
                        child: PairedDeviceCard(device: devices.last),
                      ),
                  ]
                  .animate(interval: 70.ms)
                  .fadeIn(duration: SharelyMotion.slow)
                  .slideY(begin: 0.08, curve: SharelyMotion.emphasized),
              const Spacer(),
              SharelyButton(
                label: 'Send a test photo',
                variant: SharelyButtonVariant.ink,
                onPressed: () => context.go(AppRoutes.home),
              ),
              const Gap(SharelySpacing.sm),
              TextButton(
                onPressed: () => context.go(AppRoutes.home),
                child: const Text('Skip for now'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
