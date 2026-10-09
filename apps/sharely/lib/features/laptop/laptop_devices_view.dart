import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sharely/app/routes.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/design/widgets/icon_tile.dart';
import 'package:sharely/design/widgets/section_label.dart';
import 'package:sharely/design/widgets/sharely_button.dart';
import 'package:sharely/design/widgets/surface_card.dart';
import 'package:sharely/features/laptop/widgets/laptop_page.dart';
import 'package:sharely/features/laptop/widgets/page_heading.dart';
import 'package:sharely/features/laptop/widgets/paired_phone_card.dart';
import 'package:sharely/features/pairing/state/laptop_pairing_controller.dart';
import 'package:sharely/features/pairing/state/laptop_pairing_state.dart';
import 'package:sharely/features/pairing/state/paired_devices.dart';
import 'package:sharely/features/transfer/state/connected_phones.dart';
import 'package:sharely_core/sharely_core.dart';

/// Laptop Devices (D14): who is paired, who is connected, and pairing more.
class LaptopDevicesView extends ConsumerWidget {
  const new({required this.deviceName, required this.onSendTo, super.key});

  /// This laptop's own name.
  final String deviceName;

  /// Opens Home to send to the chosen device.
  final VoidCallback onSendTo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pairing = ref.watch(laptopPairingProvider).value;
    final devices = ref.watch(pairedDevicesProvider).value ?? const [];
    final connectedIds = ref.watch(connectedPhonesProvider);
    final connectedCount = devices
        .where((device) => connectedIds.contains(device.deviceId))
        .length;
    final isOnNetwork = pairing is! LaptopNotOnNetwork;
    return LaptopPage(
      children: [
        PageHeading(
          title: 'Devices',
          subtitle:
              '$connectedCount of ${devices.length} paired devices connected.',
          trailing: SharelyButton(
            label: 'Add device',
            leadingIcon: LucideIcons.plus,
            height: SharelySizes.buttonMedium,
            isExpanded: false,
            onPressed: isOnNetwork ? () => _pairAnother(context, ref) : null,
          ),
        ),
        _ThisDeviceCard(deviceName: deviceName, isOnNetwork: isOnNetwork),
        const SectionLabel('Paired devices'),
        Wrap(
          spacing: SharelySpacing.lg,
          runSpacing: SharelySpacing.lg,
          children: [
            for (final device in devices.reversed)
              SizedBox(
                width: 280,
                child: PairedPhoneCard(
                  device: device,
                  isConnected: connectedIds.contains(device.deviceId),
                  onSend: onSendTo,
                  onRemove: () =>
                      unawaited(_confirmRemove(context, ref, device)),
                ),
              ),
          ],
        ),
        const _PairedOnlyNote(),
      ],
    );
  }

  void _pairAnother(BuildContext context, WidgetRef ref) {
    ref.read(laptopPairingProvider.notifier).showNewCode();
    context.go(AppRoutes.laptopPairing);
  }

  Future<void> _confirmRemove(
    BuildContext context,
    WidgetRef ref,
    PairedDevice device,
  ) async {
    final isConfirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove ${device.deviceName}?'),
        content: const Text(
          'It can no longer send to or receive from this laptop until it '
          'pairs again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (isConfirmed != true) return;
    await ref.read(pairedDevicesProvider.notifier).forget(device.deviceId);
    final remaining = ref.read(pairedDevicesProvider).value ?? const [];
    // With nothing paired, the laptop goes back to showing its code.
    if (remaining.isEmpty && context.mounted) _pairAnother(context, ref);
  }
}

class _ThisDeviceCard extends StatelessWidget {
  const new({required this.deviceName, required this.isOnNetwork});

  final String deviceName;
  final bool isOnNetwork;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Row(
        spacing: SharelySpacing.lg,
        children: [
          const IconTile(
            icon: LucideIcons.laptop,
            size: 48,
            radius: SharelyRadii.tile,
            color: SharelyColors.text,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 3,
              children: [
                Text(
                  'This device',
                  style: textTheme.labelSmall?.copyWith(
                    color: SharelyColors.textSecondary,
                  ),
                ),
                Text(
                  deviceName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleMedium?.copyWith(fontSize: 18),
                ),
                Text(
                  isOnNetwork
                      ? 'Visible to paired devices on this Wi-Fi'
                      : 'Connect this laptop to Wi-Fi to pair a device.',
                  style: textTheme.bodySmall?.copyWith(
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

class _PairedOnlyNote extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: 10,
      children: [
        const Icon(
          LucideIcons.shieldCheck,
          size: 15,
          color: SharelyColors.textSecondary,
        ),
        Expanded(
          child: Text(
            'Only paired devices can send to this laptop.',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: SharelyColors.textSecondary),
          ),
        ),
      ],
    );
  }
}
