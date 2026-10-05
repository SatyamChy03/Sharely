import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sharely/app/device_platform.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely_core/sharely_core.dart';

/// White card naming a paired device, with a "Paired" chip.
class PairedDeviceCard extends StatelessWidget {
  const new({required this.device, super.key});

  final PairedDevice device;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isPhone =
        device.platform == DevicePlatform.android ||
        device.platform == DevicePlatform.ios;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: SharelyColors.surface,
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(SharelySpacing.lg),
        child: Row(
          spacing: 14,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: SharelyColors.ink,
                borderRadius: BorderRadius.all(Radius.circular(13)),
              ),
              child: Icon(
                isPhone ? LucideIcons.smartphone : LucideIcons.laptop,
                size: 22,
                color: SharelyColors.accentOnInk,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(device.deviceName, style: textTheme.titleMedium),
                  Text(
                    platformDisplayName(device.platform),
                    style: textTheme.bodySmall?.copyWith(
                      color: SharelyColors.slate,
                    ),
                  ),
                ],
              ),
            ),
            const _PairedChip(),
          ],
        ),
      ),
    );
  }
}

class _PairedChip extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: SharelyColors.ink,
        borderRadius: BorderRadius.all(SharelyRadii.chip),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          'Paired',
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: SharelyColors.surface),
        ),
      ),
    );
  }
}
