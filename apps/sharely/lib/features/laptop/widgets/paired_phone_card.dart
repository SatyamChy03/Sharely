import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sharely/app/device_platform.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/design/widgets/icon_tile.dart';
import 'package:sharely/design/widgets/sharely_button.dart';
import 'package:sharely/design/widgets/status_badge.dart';
import 'package:sharely/design/widgets/surface_card.dart';
import 'package:sharely_core/sharely_core.dart';

/// One paired device on the laptop's Devices page (D14).
class PairedPhoneCard extends StatelessWidget {
  const new({
    required this.device,
    required this.isConnected,
    required this.onSend,
    required this.onRemove,
    super.key,
  });

  final PairedDevice device;
  final bool isConnected;
  final VoidCallback onSend;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isPhone =
        device.platform == DevicePlatform.android ||
        device.platform == DevicePlatform.ios;
    return SurfaceCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        spacing: SharelySpacing.lg,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconTile(
                icon: isPhone ? LucideIcons.smartphone : LucideIcons.laptop,
                radius: SharelyRadii.tile,
                color: isConnected
                    ? SharelyColors.primary
                    : SharelyColors.textSecondary,
              ),
              StatusBadge(
                label: isConnected ? 'Connected' : 'Offline',
                tone: isConnected ? StatusTone.connected : StatusTone.offline,
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 4,
            children: [
              Text(
                device.deviceName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleMedium,
              ),
              Text(
                isConnected
                    ? '${platformDisplayName(device.platform)} · Wi-Fi'
                    : platformDisplayName(device.platform),
                style: textTheme.bodySmall?.copyWith(
                  color: SharelyColors.textSecondary,
                ),
              ),
            ],
          ),
          _buildActions(),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Row(
      children: [
        if (isConnected)
          SharelyButton(
            label: 'Send',
            leadingIcon: LucideIcons.arrowUp,
            height: SharelySizes.buttonSmall,
            isExpanded: false,
            onPressed: onSend,
          ),
        const Spacer(),
        TextButton(
          onPressed: onRemove,
          style: TextButton.styleFrom(
            foregroundColor: SharelyColors.dangerText,
          ),
          child: const Text('Remove'),
        ),
      ],
    );
  }
}
