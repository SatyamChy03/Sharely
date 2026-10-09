import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sharely/app/device_platform.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/design/widgets/icon_tile.dart';
import 'package:sharely/design/widgets/sharely_button.dart';
import 'package:sharely/design/widgets/status_badge.dart';
import 'package:sharely_core/sharely_core.dart';

/// One paired laptop on the phone's Devices tab, with what can be done to
/// it: connect or disconnect, and remove.
class LaptopDeviceTile extends StatelessWidget {
  const new({
    required this.laptop,
    required this.isConnected,
    required this.onConnect,
    required this.onDisconnect,
    required this.onRemove,
    super.key,
  });

  final PairedDevice laptop;
  final bool isConnected;

  /// Exactly one of these is offered. Null while a transfer is running.
  final VoidCallback? onConnect;
  final VoidCallback? onDisconnect;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          Row(
            spacing: SharelySpacing.md,
            children: [
              IconTile(
                icon: LucideIcons.laptop,
                size: 42,
                color: isConnected
                    ? SharelyColors.primary
                    : SharelyColors.textSecondary,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 3,
                  children: [
                    Text(
                      laptop.deviceName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleSmall,
                    ),
                    StatusBadge(
                      label: isConnected
                          ? 'Connected · Wi-Fi'
                          : 'Not connected · '
                                '${platformDisplayName(laptop.platform)}',
                      tone: isConnected
                          ? StatusTone.connected
                          : StatusTone.offline,
                      isPlain: true,
                    ),
                  ],
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
      spacing: SharelySpacing.sm,
      children: [
        Expanded(
          child: isConnected
              ? SharelyButton(
                  label: 'Disconnect',
                  variant: SharelyButtonVariant.secondary,
                  height: 40,
                  onPressed: onDisconnect,
                )
              : SharelyButton(
                  label: 'Connect',
                  height: 40,
                  onPressed: onConnect,
                ),
        ),
        Expanded(
          child: SharelyButton(
            label: 'Remove',
            leadingIcon: LucideIcons.trash2,
            variant: SharelyButtonVariant.danger,
            height: 40,
            onPressed: onRemove,
          ),
        ),
      ],
    );
  }
}
