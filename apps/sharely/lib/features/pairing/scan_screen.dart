import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sharely/app/routes.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/features/pairing/state/phone_pairing_controller.dart';
import 'package:sharely/features/pairing/state/phone_pairing_state.dart';
import 'package:sharely/features/pairing/widgets/scan_camera_area.dart';
import 'package:sharely/features/pairing/widgets/scan_status_card.dart';
import 'package:sharely/features/pairing/widgets/step_progress.dart';

/// Get started step 2 of 3: scan the QR code shown on the laptop.
class ScanScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pairingState = ref.watch(phonePairingProvider);
    ref.listen(phonePairingProvider, (previous, next) {
      if (next is PhonePaired) context.go(AppRoutes.connected);
    });
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _ScanHeader(),
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
              const Gap(SharelySpacing.xl),
              const Expanded(child: ScanCameraArea()),
              const Gap(SharelySpacing.lg),
              ScanStatusCard(
                state: pairingState,
                onScanAgain: ref.read(phonePairingProvider.notifier).scanAgain,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScanHeader extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
        const StepProgress(currentStep: 2),
      ],
    );
  }
}
