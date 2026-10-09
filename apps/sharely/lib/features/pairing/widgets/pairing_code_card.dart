import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/design/typography.dart';
import 'package:sharely/design/widgets/sharely_button.dart';
import 'package:sharely/design/widgets/surface_card.dart';
import 'package:sharely/features/pairing/state/laptop_pairing_state.dart';
import 'package:sharely/features/pairing/widgets/expiry_countdown.dart';

/// The typed-code fallback: six digits, a copy button and the time left.
class PairingCodeCard extends StatelessWidget {
  const new({required this.waiting, super.key});

  final LaptopWaitingForPhone waiting;

  @override
  Widget build(BuildContext context) {
    final code = waiting.code;
    final spacedCode = '${code.substring(0, 3)} ${code.substring(3)}';
    return SurfaceCard(
      radius: SharelyRadii.zone,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 10,
        children: [
          Text(
            'Or enter this code on your phone',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
              color: SharelyColors.textSecondary,
            ),
          ),
          Wrap(
            spacing: SharelySpacing.md,
            runSpacing: SharelySpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SelectableText(
                spacedCode,
                style: sharelyMonoStyle(
                  size: 36,
                  color: SharelyColors.text,
                  tracking: 2,
                ),
              ),
              SharelyButton(
                label: 'Copy',
                leadingIcon: LucideIcons.copy,
                variant: SharelyButtonVariant.secondary,
                height: 40,
                isExpanded: false,
                onPressed: () =>
                    unawaited(Clipboard.setData(ClipboardData(text: code))),
              ),
            ],
          ),
          ExpiryCountdown(expiresAt: waiting.expiresAt),
        ],
      ),
    );
  }
}
