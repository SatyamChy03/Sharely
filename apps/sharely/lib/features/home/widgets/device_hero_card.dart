import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/design/widgets/sharely_button.dart';
import 'package:sharely_core/sharely_core.dart';

/// Dark card at the top of the phone home: the paired laptop and Send.
class DeviceHeroCard extends StatelessWidget {
  const new({required this.laptop, required this.onSend, super.key});

  final PairedDevice laptop;
  final VoidCallback? onSend;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: SharelyColors.ink,
        borderRadius: BorderRadius.all(SharelyRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            spacing: SharelySpacing.md,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  color: SharelyColors.inkRaisedHigh,
                  borderRadius: BorderRadius.all(Radius.circular(14)),
                ),
                child: const Icon(
                  LucideIcons.laptop,
                  color: SharelyColors.accentOnInk,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      laptop.deviceName,
                      style: textTheme.titleMedium?.copyWith(
                        color: SharelyColors.surface,
                      ),
                    ),
                    Text(
                      'Paired',
                      style: textTheme.bodySmall?.copyWith(
                        color: SharelyColors.onInkSoft,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Gap(18),
          SharelyButton(
            label: 'Send to laptop',
            trailingIcon: LucideIcons.arrowUp,
            onPressed: onSend,
          ),
        ],
      ),
    );
  }
}
