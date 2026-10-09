import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sharely/design/tokens.dart';

/// The most common reason a phone can't reach a laptop, and its fix.
class FirewallHint extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final firewall = Platform.isWindows ? 'Windows Firewall' : 'your firewall';
    final style = Theme.of(context).textTheme.bodySmall
        ?.copyWith(color: SharelyColors.textSecondary);
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: SharelySpacing.sm,
      children: [
        const Icon(
          LucideIcons.shieldCheck,
          size: 15,
          color: SharelyColors.primary,
        ),
        Flexible(
          child: Text.rich(
            TextSpan(
              text: "Phone can't find this laptop? ",
              children: [
                TextSpan(
                  text: 'Allow Sharely through $firewall.',
                  style: const TextStyle(color: SharelyColors.text),
                ),
              ],
            ),
            style: style,
          ),
        ),
      ],
    );
  }
}
