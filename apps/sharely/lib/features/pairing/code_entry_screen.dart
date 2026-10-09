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
import 'package:sharely/features/pairing/widgets/laptop_choice_list.dart';
import 'package:sharely/features/pairing/widgets/pairing_code_field.dart';
import 'package:sharely/features/pairing/widgets/pairing_issue_text.dart';
import 'package:sharely/features/pairing/widgets/pairing_progress_view.dart';
import 'package:sharely/features/pairing/widgets/pairing_step_header.dart';

/// Pairing step 1 without a camera (M03): type the code the laptop shows.
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
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
          child: switch (pairing) {
            PhoneSearchingForLaptop() => PairingProgressView(
              onCancel: controller.scanAgain,
            ),
            PhoneConnecting(:final laptopName) => PairingProgressView(
              laptopName: laptopName,
              onCancel: controller.scanAgain,
            ),
            _ => _buildEntry(pairing, controller),
          },
        ),
      ),
    );
  }

  Widget _buildEntry(
    PhonePairingState pairing,
    PhonePairingController controller,
  ) {
    final textTheme = Theme.of(context).textTheme;
    final issue = pairing is PhonePairingFailed ? pairing.issue : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PairingStepHeader(currentStep: 1, onBack: () => context.pop()),
        const Gap(22),
        Text('Enter pairing code', style: textTheme.headlineLarge),
        const Gap(SharelySpacing.sm),
        Text(
          "You'll find it on your laptop, under the QR code.",
          style: textTheme.bodyLarge?.copyWith(
            height: 1.5,
            color: SharelyColors.textSecondary,
          ),
        ),
        const Gap(22),
        PairingCodeField(
          hasError: issue != null,
          onChanged: (code) => setState(() => _code = code),
        ),
        const Gap(SharelySpacing.md),
        if (issue != null) _IssueNote(issue) else const _ExpiryNote(),
        const Gap(22),
        SharelyButton(label: 'Connect', onPressed: _isComplete ? _pair : null),
        const Gap(SharelySpacing.lg),
        if (pairing case PhoneChoosingLaptop(:final laptops, :final code))
          Expanded(
            child: SingleChildScrollView(
              child: LaptopChoiceList(
                laptops: laptops,
                onChosen: (laptop) =>
                    unawaited(controller.pairWithFoundLaptop(laptop, code)),
              ),
            ),
          ),
      ],
    );
  }
}

class _ExpiryNote extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: SharelySpacing.sm,
      children: [
        const Icon(
          LucideIcons.clock,
          size: 14,
          color: SharelyColors.textSecondary,
        ),
        Expanded(
          child: Text(
            'The code changes every 5 minutes.',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: SharelyColors.textSecondary),
          ),
        ),
      ],
    );
  }
}

class _IssueNote extends StatelessWidget {
  const new(this.issue);

  final PhonePairingIssue issue;

  @override
  Widget build(BuildContext context) {
    final text = describePairingIssue(issue);
    return Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: SharelySpacing.sm,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              LucideIcons.circleAlert,
              size: 14,
              color: SharelyColors.dangerText,
            ),
          ),
          Expanded(
            child: Text(
              '${text.title}. ${text.fix}',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: SharelyColors.dangerText),
            ),
          ),
        ],
      ),
    );
  }
}
