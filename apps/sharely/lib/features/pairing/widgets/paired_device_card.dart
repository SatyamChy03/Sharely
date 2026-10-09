import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sharely/app/device_platform.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely_core/sharely_core.dart';

/// White card naming a paired device, with a status chip.
class PairedDeviceCard extends StatelessWidget {
  const new({required this.device, this.isConnected, super.key});

  final PairedDevice device;

  /// Null where live status is unknown; the chip then only says "Paired".
  final bool? isConnected;

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
            _StatusChip(isConnected: isConnected),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const new({required this.isConnected});

  final bool? isConnected;

  @override
  Widget build(BuildContext context) {
    final (label, background, foreground) = switch (isConnected) {
      null => ('Paired', SharelyColors.ink, SharelyColors.surface),
      true => ('Connected', SharelyColors.accent, SharelyColors.onAccent),
      false => ('Not connected', SharelyColors.mistLight, SharelyColors.slate),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: const BorderRadius.all(SharelyRadii.chip),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: foreground),
        ),
      ),
    );
  }
}
