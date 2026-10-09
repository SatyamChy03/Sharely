import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/design/typography.dart';

/// Left column of the laptop get-started screen: promise and three steps.
class LaptopPairingIntro extends StatelessWidget {
  const new({required this.isPaired, this.hasReceivedFile = false, super.key});

  final bool isPaired;
  final bool hasReceivedFile;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Your phone is\none scan away.', style: textTheme.displayLarge),
        const Gap(SharelySpacing.xl),
        Text(
          'Pair once, then drop anything on this window and it lands on '
          'your phone. No cable, no cloud, no account.',
          style: textTheme.bodyLarge?.copyWith(color: SharelyColors.onInkSoft),
        ),
        const Gap(SharelySpacing.xl),
        _Step(
          number: '01',
          label: 'Install Sharely on your phone',
          isDone: isPaired,
        ),
        _Step(
          number: '02',
          label: 'Scan the code with the app',
          isCurrent: !isPaired,
          isDone: isPaired,
        ),
        _Step(
          number: '03',
          label: 'Send a test photo',
          isCurrent: isPaired && !hasReceivedFile,
          isDone: hasReceivedFile,
        ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const new({
    required this.number,
    required this.label,
    this.isCurrent = false,
    this.isDone = false,
  });

  final String number;
  final String label;
  final bool isCurrent;
  final bool isDone;

  @override
  Widget build(BuildContext context) {
    final emphasis = isCurrent || isDone;
    final labelStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(
      fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w400,
      color: emphasis ? SharelyColors.surface : SharelyColors.onInkMuted,
    );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: SharelySpacing.md),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: SharelyColors.inkBorder)),
      ),
      child: Row(
        spacing: SharelySpacing.lg,
        children: [
          Text(
            number,
            style: sharelyMonoStyle(
              size: 14,
              color: isCurrent
                  ? SharelyColors.accentOnInk
                  : SharelyColors.onInkMuted,
            ),
          ),
          Expanded(child: Text(label, style: labelStyle)),
          if (isCurrent || isDone)
            Text(
              isDone ? 'Done' : 'Now',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: isDone
                    ? SharelyColors.accentOnInk
                    : SharelyColors.onInkMuted,
              ),
            ),
        ],
      ),
    );
  }
}
