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
import 'package:sharely/features/home/widgets/laptop_device_tile.dart';
import 'package:sharely/features/pairing/state/local_identity.dart';
import 'package:sharely/features/pairing/state/paired_devices.dart';
import 'package:sharely/features/pairing/state/phone_pairing_controller.dart';
import 'package:sharely/features/transfer/state/laptop_connection_controller.dart';
import 'package:sharely/features/transfer/state/laptop_connection_state.dart';
import 'package:sharely/features/transfer/state/transfer_in_flight.dart';
import 'package:sharely_core/sharely_core.dart';

/// The Devices tab (M13): choose which laptop to use, disconnect from it,
/// remove it, or pair another.
class DevicesTabView extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devices = ref.watch(pairedDevicesProvider).value ?? const [];
    final connection = ref.watch(laptopConnectionProvider);
    final isBusy = ref.watch(isTransferInFlightProvider);
    final textTheme = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(SharelySpacing.page),
      children: [
        SizedBox(
          height: SharelySizes.minTouchTarget,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'Devices',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.headlineMedium,
                ),
              ),
              SharelyButton(
                label: 'Add device',
                leadingIcon: LucideIcons.plus,
                height: SharelySizes.buttonMedium,
                isExpanded: false,
                onPressed: isBusy
                    ? null
                    : () => _pairAnother(context, ref, devices),
              ),
            ],
          ),
        ),
        const SizedBox(height: SharelySpacing.lg),
        const _ThisPhoneCard(),
        const SizedBox(height: SharelySpacing.lg),
        if (devices.isNotEmpty) ...[
          const SectionLabel('Paired laptops'),
          const SizedBox(height: SharelySpacing.sm),
          SurfaceCard(
            radius: SharelyRadii.zone,
            padding: const EdgeInsets.all(SharelySpacing.xs),
            child: Column(
              children: [
                // The laptop in use is the last paired or chosen; it leads.
                for (final laptop in devices.reversed)
                  _buildTile(context, ref, laptop, connection, isBusy),
              ],
            ),
          ),
          const SizedBox(height: SharelySpacing.lg),
        ],
        _Note(isBusy: isBusy),
      ],
    );
  }

  Widget _buildTile(
    BuildContext context,
    WidgetRef ref,
    PairedDevice laptop,
    LaptopConnectionState connection,
    bool isBusy,
  ) {
    final isConnected =
        connection is LaptopConnected &&
        connection.laptop.deviceId == laptop.deviceId;
    return LaptopDeviceTile(
      laptop: laptop,
      isConnected: isConnected,
      onConnect: isBusy ? null : () => unawaited(_connectTo(ref, laptop)),
      onDisconnect: isBusy
          ? null
          : ref.read(laptopConnectionProvider.notifier).disconnect,
      onRemove: isBusy
          ? null
          : () => unawaited(_confirmRemove(context, ref, laptop)),
    );
  }

  /// Switches to [laptop], or reconnects if it is already the one in use.
  Future<void> _connectTo(WidgetRef ref, PairedDevice laptop) async {
    await ref.read(pairedDevicesProvider.notifier).makeActive(laptop.deviceId);
    ref.read(laptopConnectionProvider.notifier).connect();
  }

  void _pairAnother(
    BuildContext context,
    WidgetRef ref,
    List<PairedDevice> devices,
  ) {
    // The scanner still holds the last pairing's result; start it clean.
    ref.invalidate(phonePairingProvider);
    // Pushed when there is a Home to come back to; the first pairing has none.
    if (devices.isEmpty) return context.go(AppRoutes.scan);
    unawaited(context.push(AppRoutes.scan));
  }

  Future<void> _confirmRemove(
    BuildContext context,
    WidgetRef ref,
    PairedDevice laptop,
  ) async {
    final isConfirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove ${laptop.deviceName}?'),
        content: const Text(
          "You'll need to scan its code again before sending anything to it.",
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
    final devices = ref.read(pairedDevicesProvider.notifier);
    await devices.forget(laptop.deviceId);
    final remaining = ref.read(pairedDevicesProvider).value ?? const [];
    if (remaining.isEmpty && context.mounted) context.go(AppRoutes.welcome);
  }
}

class _ThisPhoneCard extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final name = ref.watch(localHelloProvider).value?.deviceName ?? '';
    return SurfaceCard(
      radius: SharelyRadii.zone,
      padding: const EdgeInsets.all(14),
      child: Row(
        spacing: 14,
        children: [
          const IconTile(
            icon: LucideIcons.smartphone,
            color: SharelyColors.text,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                Text(
                  'This phone',
                  style: textTheme.labelSmall?.copyWith(
                    color: SharelyColors.textSecondary,
                  ),
                ),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelLarge,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const new({required this.isBusy});

  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 10,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Icon(
            LucideIcons.shieldCheck,
            size: 15,
            color: SharelyColors.textSecondary,
          ),
        ),
        Expanded(
          child: Text(
            isBusy
                ? 'Finish or cancel the transfer to change laptops.'
                : 'Only laptops you have paired can send you files. Files '
                      'go to the laptop you are connected to.',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: SharelyColors.textSecondary),
          ),
        ),
      ],
    );
  }
}
