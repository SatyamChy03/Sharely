import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sharely/app/routes.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/design/widgets/sharely_button.dart';
import 'package:sharely/features/pairing/state/phone_pairing_controller.dart';
import 'package:sharely/features/pairing/state/phone_pairing_state.dart';
import 'package:sharely/features/pairing/widgets/pairing_failed_view.dart';
import 'package:sharely/features/pairing/widgets/pairing_progress_view.dart';
import 'package:sharely/features/pairing/widgets/pairing_step_header.dart';
import 'package:sharely/features/pairing/widgets/scan_camera_area.dart';

/// Pairing step 1 (M02): scan the QR code shown on the laptop.
class ScanScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pairingState = ref.watch(phonePairingProvider);
    final controller = ref.read(phonePairingProvider.notifier);
    ref.listen(phonePairingProvider, (previous, next) {
      if (next is PhonePaired) context.go(AppRoutes.connected);
    });
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: switch (pairingState) {
            PhoneConnecting(:final laptopName) => PairingProgressView(
              laptopName: laptopName,
              onCancel: controller.scanAgain,
            ),
            PhonePairingFailed(:final issue) => PairingFailedView(
              issue: issue,
              onTryAgain: controller.scanAgain,
            ),
            _ => const _ScanStep(),
          },
        ),
      ),
    );
  }
}

class _ScanStep extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PairingStepHeader(currentStep: 1, onBack: () => context.pop()),
        const Gap(22),
        Text('Connect your laptop', style: textTheme.headlineLarge),
        const Gap(SharelySpacing.sm),
        Text(
          'Scan the code on your laptop to pair your devices.',
          style: textTheme.bodyLarge?.copyWith(
            height: 1.5,
            color: SharelyColors.textSecondary,
          ),
        ),
        const Gap(22),
        // Square as designed, shrinking only on short phones.
        const Expanded(
          child: Align(
            alignment: Alignment.topCenter,
            child: AspectRatio(aspectRatio: 1, child: ScanCameraArea()),
          ),
        ),
        const Gap(SharelySpacing.lg),
        SharelyButton(
          label: 'Or enter the 6-digit code',
          leadingIcon: LucideIcons.keyboard,
          variant: SharelyButtonVariant.secondary,
          onPressed: () {
            ref.read(phonePairingProvider.notifier).scanAgain();
            unawaited(context.push(AppRoutes.typeCode));
          },
        ),
      ],
    );
  }
}
