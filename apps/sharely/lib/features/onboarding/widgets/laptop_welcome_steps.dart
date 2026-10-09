import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/design/typography.dart';
import 'package:sharely/design/widgets/sharely_button.dart';

/// "Get started" on the laptop welcome: three steps and the pairing action.
class LaptopWelcomeSteps extends StatelessWidget {
  const new({required this.onPairPhone, super.key});

  final VoidCallback onPairPhone;

  static const List<({String title, String body})> _steps = [
    (title: 'Install Sharely on your phone', body: 'On your Android phone.'),
    (title: 'Scan the code on this screen', body: 'Or type the 6-digit code.'),
    (title: 'Drop a file to send it', body: "That's it."),
  ];

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Get started', style: textTheme.headlineLarge),
          Padding(
            padding: const EdgeInsets.only(top: SharelySpacing.sm, bottom: 28),
            child: Text(
              'Pair your phone once. It takes about ten seconds.',
              style: textTheme.bodyLarge?.copyWith(
                color: SharelyColors.textSecondary,
              ),
            ),
          ),
          for (final (index, step) in _steps.indexed)
            _Step(number: index + 1, title: step.title, body: step.body),
          const SizedBox(height: 28),
          SharelyButton(
            label: 'Pair a phone',
            height: 48,
            trailingIcon: LucideIcons.arrowRight,
            onPressed: onPairPhone,
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const new({required this.number, required this.title, required this.body});

  final int number;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(bottom: SharelySpacing.xs),
      padding: const EdgeInsets.symmetric(vertical: SharelySpacing.md),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: SharelyColors.line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                Text(title, style: textTheme.titleSmall),
                Text(
                  body,
                  style: textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w400,
                    color: SharelyColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
