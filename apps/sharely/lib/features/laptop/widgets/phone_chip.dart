import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sharely/design/tokens.dart';

/// Ink pill naming the paired phone, with a dot when it is connected.
class PhoneChip extends StatelessWidget {
  const new({required this.phoneName, required this.isConnected, super.key});

  final String phoneName;
  final bool isConnected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$phoneName, ${isConnected ? 'connected' : 'not connected'}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 7, 16, 7),
        decoration: const BoxDecoration(
          color: SharelyColors.ink,
          borderRadius: BorderRadius.all(SharelyRadii.chip),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 10,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: const BoxDecoration(
                color: SharelyColors.inkRaisedHigh,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.smartphone,
                size: 16,
                color: SharelyColors.accentOnInk,
              ),
            ),
            Text(
              phoneName,
              style: Theme.of(context).textTheme.labelLarge
                  ?.copyWith(color: SharelyColors.surface, fontSize: 14),
            ),
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: isConnected
                    ? SharelyColors.accent
                    : SharelyColors.onInkMuted,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
