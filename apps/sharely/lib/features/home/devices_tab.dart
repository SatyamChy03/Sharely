import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sharely/app/routes.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/design/widgets/sharely_button.dart';
import 'package:sharely/features/home/widgets/laptop_device_tile.dart';
import 'package:sharely/features/pairing/state/paired_devices.dart';
import 'package:sharely/features/pairing/state/phone_pairing_controller.dart';
import 'package:sharely/features/transfer/state/laptop_connection_controller.dart';
import 'package:sharely/features/transfer/state/laptop_connection_state.dart';
import 'package:sharely/features/transfer/state/transfer_in_flight.dart';
import 'package:sharely_core/sharely_core.dart';

/// The phone's paired laptops: choose which one to use, disconnect from it,
/// forget it, or pair another.
class DevicesTabView extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devices = ref.watch(pairedDevicesProvider).value ?? const [];
    final connection = ref.watch(laptopConnectionProvider);
    final isBusy = ref.watch(isTransferInFlightProvider);
    final textTheme = Theme.of(context).textTheme;
    final hint = _hint(devices.length, isBusy: isBusy);
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 104),
      children: [
        Text('Devices', style: textTheme.headlineMedium),
        if (hint != null)
          Padding(
            padding: const EdgeInsets.only(top: SharelySpacing.sm),
            child: Text(
              hint,
              style: textTheme.bodyMedium?.copyWith(color: SharelyColors.slate),
            ),
          ),
        const SizedBox(height: SharelySpacing.lg),
        // The laptop in use is the last one paired or chosen; show it first.
        for (final laptop in devices.reversed)
          Padding(
            padding: const EdgeInsets.only(bottom: SharelySpacing.xl),
            child: _buildTile(context, ref, laptop, connection, isBusy),
          ),
        SharelyButton(
          label: devices.isEmpty ? 'Pair your laptop' : 'Pair another laptop',
          variant: SharelyButtonVariant.ink,
          leadingIcon: LucideIcons.plus,
          onPressed: isBusy ? null : () => _pairAnother(context, ref, devices),
        ),
      ],
    );
  }

  String? _hint(int laptopCount, {required bool isBusy}) {
    if (isBusy) return 'Finish or cancel the transfer to change laptops.';
    if (laptopCount > 1) return 'Files go to the laptop you are connected to.';
    return null;
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
      onForget: isBusy
          ? null
          : () => unawaited(_confirmForget(context, ref, laptop)),
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

  Future<void> _confirmForget(
    BuildContext context,
    WidgetRef ref,
    PairedDevice laptop,
  ) async {
    final isConfirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Forget ${laptop.deviceName}?'),
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
            child: const Text('Forget'),
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
