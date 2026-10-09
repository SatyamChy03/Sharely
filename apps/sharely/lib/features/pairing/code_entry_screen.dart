import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sharely/app/routes.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/design/widgets/sharely_button.dart';
import 'package:sharely/features/pairing/state/phone_pairing_controller.dart';
import 'package:sharely/features/pairing/state/phone_pairing_state.dart';
import 'package:sharely/features/pairing/widgets/laptop_choice_list.dart';
import 'package:sharely/features/pairing/widgets/pairing_code_field.dart';
import 'package:sharely/features/pairing/widgets/scan_status_card.dart';
import 'package:sharely/features/pairing/widgets/step_progress.dart';

/// Get started step 2, without a camera: type the code the laptop shows.
class CodeEntryScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<CodeEntryScreen> createState() => _CodeEntryScreenState();
}

class _CodeEntryScreenState extends ConsumerState<CodeEntryScreen> {
  String _code = '';

  bool get _isComplete => _code.length == PairingCodeField.length;

  void _pair() => unawaited(
    ref.read(phonePairingProvider.notifier).pairWithTypedCode(_code),
  );

  @override
  Widget build(BuildContext context) {
    final pairing = ref.watch(phonePairingProvider);
    final controller = ref.read(phonePairingProvider.notifier);
    ref.listen(phonePairingProvider, (_, next) {
      if (next is PhonePaired) context.go(AppRoutes.connected);
    });
    final isWorking =
        pairing is PhoneSearchingForLaptop || pairing is PhoneConnecting;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 22,
            children: [
              const _Header(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: SharelySpacing.sm,
                children: [
                  Text(
                    'Type the code from your laptop',
                    style: textTheme.headlineLarge,
                  ),
                  Text(
                    "It's under the QR code in Sharely on your laptop and "
                    'changes every 5 minutes.',
                    style: textTheme.bodyLarge?.copyWith(
                      color: SharelyColors.slate,
                    ),
                  ),
                ],
              ),
              PairingCodeField(
                isEnabled: !isWorking,
                onChanged: (code) => setState(() => _code = code),
              ),
              Expanded(child: _buildStatus(pairing, controller)),
              SharelyButton(
                label: isWorking ? 'Pairing…' : 'Pair',
                variant: SharelyButtonVariant.ink,
                onPressed: _isComplete && !isWorking ? _pair : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatus(
    PhonePairingState pairing,
    PhonePairingController controller,
  ) {
    return SingleChildScrollView(
      child: switch (pairing) {
        PhoneChoosingLaptop(:final laptops, :final code) => LaptopChoiceList(
          laptops: laptops,
          onChosen: (laptop) =>
              unawaited(controller.pairWithFoundLaptop(laptop, code)),
        ),
        PhoneSearchingForLaptop() => const _SearchingNote(),
        PhoneConnecting() || PhonePairingFailed() => ScanStatusCard(
          state: pairing,
          onScanAgain: controller.scanAgain,
        ),
        _ => const SizedBox.shrink(),
      },
    );
  }
}

class _Header extends StatelessWidget {
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

class _SearchingNote extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: SharelySpacing.md,
      children: [
        const SizedBox.square(
          dimension: 20,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
        Expanded(
          child: Text(
            'Looking for your laptop on this Wi-Fi…',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: SharelyColors.slate),
          ),
        ),
      ],
    );
  }
}
