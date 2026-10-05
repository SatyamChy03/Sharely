import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sharely/design/tokens.dart';

/// Under the QR card: the most common reason a phone can't reach a laptop.
class FirewallHint extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final firewall = Platform.isWindows ? 'Windows Firewall' : 'your firewall';
    final style = Theme.of(context).textTheme.bodyMedium
        ?.copyWith(color: SharelyColors.onInkSoft, height: 1.4);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.all(Radius.circular(20)),
        border: Border.all(color: SharelyColors.inkBorderStrong),
      ),
      child: Row(
        spacing: SharelySpacing.md,
        children: [
          const Icon(
            LucideIcons.shieldCheck,
            size: 18,
            color: SharelyColors.accentOnInk,
          ),
          Expanded(
            child: Text.rich(
              TextSpan(
                text: "Phone can't find this laptop? ",
                children: [
                  TextSpan(
                    text: 'Allow Sharely through $firewall.',
                    style: style?.copyWith(
                      color: SharelyColors.surface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              style: style,
            ),
          ),
        ],
      ),
    );
  }
}
