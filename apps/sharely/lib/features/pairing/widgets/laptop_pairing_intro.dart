import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/design/typography.dart';
import 'package:sharely/features/pairing/state/laptop_pairing_state.dart';
import 'package:sharely/features/pairing/widgets/pairing_code_card.dart';

/// Left column of laptop pairing (D02): what to do, then the typed code.
class LaptopPairingIntro extends StatelessWidget {
  const new({required this.waiting, super.key});

  final LaptopWaitingForPhone waiting;

  static const _steps = [
    'Open Sharely on your phone',
    'Tap “Get started”, or “Add device”',
    'Point the camera at this code',
  ];

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Pair your phone', style: textTheme.displaySmall),
        const Gap(10),
        Text(
          'Open Sharely on your phone and scan this code.',
          style: textTheme.bodyLarge?.copyWith(
            color: SharelyColors.textSecondary,
          ),
        ),
        const Gap(28),
        for (final (index, step) in _steps.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _NumberedStep(number: index + 1, label: step),
          ),
        const Gap(14),
        PairingCodeCard(waiting: waiting),
      ],
    );
  }
}

class _NumberedStep extends StatelessWidget {
  const new({required this.number, required this.label});

  final int number;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: 14,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(SharelyRadii.row),
            border: Border.all(color: SharelyColors.lineStrong),
          ),
          child: Text(
            '$number',
            style: sharelyMonoStyle(size: 13, color: SharelyColors.primary),
          ),
        ),
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    );
  }
}
