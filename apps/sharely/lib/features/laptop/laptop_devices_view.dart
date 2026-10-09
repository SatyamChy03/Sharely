import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/design/typography.dart';
import 'package:sharely/design/widgets/sharely_button.dart';
import 'package:sharely/features/laptop/widgets/pair_new_device_panel.dart';
import 'package:sharely/features/pairing/state/laptop_pairing_controller.dart';
import 'package:sharely/features/pairing/state/laptop_pairing_state.dart';
import 'package:sharely/features/pairing/state/paired_devices.dart';
import 'package:sharely/features/pairing/widgets/paired_device_card.dart';
import 'package:sharely/features/transfer/state/connected_phones.dart';
import 'package:sharely_core/sharely_core.dart';

/// Laptop "Devices": who is paired, who is connected, and pairing one more.
class LaptopDevicesView extends ConsumerWidget {
  const new({super.key});

  static const _wideLayoutMinWidth = 960.0;
  static const _qrPanelWidth = 480.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pairing = ref.watch(laptopPairingProvider).value;
    final devices = ref.watch(pairedDevicesProvider).value ?? const [];
    final connectedIds = ref.watch(connectedPhonesProvider);
    ref.listen(laptopPairingProvider, (previous, next) {
      final paired = next.value;
      if (previous?.value is! LaptopWaitingForPhone) return;
      if (paired is! LaptopPairedWithPhone) return;
      // Cancelling also lands here; only a new device earns the message.
      if (devices.any((device) => device.deviceId == paired.phone.deviceId)) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Paired with ${paired.phone.deviceName}.')),
      );
    });
    final controller = ref.read(laptopPairingProvider.notifier);
    final list = _DeviceList(
      devices: devices,
      connectedIds: connectedIds,
      isOnNetwork: pairing is! LaptopNotOnNetwork,
      onPairNew: pairing is LaptopPairedWithPhone
          ? controller.showNewCode
          : null,
    );
    final qrPanel = pairing is LaptopWaitingForPhone
        ? PairNewDevicePanel(waiting: pairing, onCancel: controller.stopPairing)
        : null;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
        child: _arrange(
          list: list,
          qrPanel: qrPanel,
          isWide: constraints.maxWidth >= _wideLayoutMinWidth,
        ),
      ),
    );
  }

  Widget _arrange({
    required Widget list,
    required Widget? qrPanel,
    required bool isWide,
  }) {
    if (qrPanel == null) return list;
    if (!isWide) return Column(spacing: 24, children: [qrPanel, list]);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 32,
      children: [
        Expanded(child: list),
        SizedBox(width: _qrPanelWidth, child: qrPanel),
      ],
    );
  }
}

class _DeviceList extends StatelessWidget {
  const new({
    required this.devices,
    required this.connectedIds,
    required this.isOnNetwork,
    required this.onPairNew,
  });

  final List<PairedDevice> devices;
  final Set<String> connectedIds;
  final bool isOnNetwork;

  /// Null while a code is already on show.
  final VoidCallback? onPairNew;

  static const _pairButtonWidth = 260.0;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final connectedCount = devices
        .where((device) => connectedIds.contains(device.deviceId))
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 18,
      children: [
        Text(
          'Devices',
          style: textTheme.headlineMedium?.copyWith(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.2,
          ),
        ),
        Text(
          '$connectedCount of ${devices.length} connected',
          style: sharelyMonoStyle(size: 13, color: SharelyColors.slate),
        ),
        for (final device in devices.reversed)
          PairedDeviceCard(
            device: device,
            isConnected: connectedIds.contains(device.deviceId),
          ),
        if (!isOnNetwork)
          Text(
            'Connect this laptop to Wi-Fi to pair a device.',
            style: textTheme.bodyMedium?.copyWith(color: SharelyColors.slate),
          ),
        SizedBox(
          width: _pairButtonWidth,
          child: SharelyButton(
            label: 'Pair a new device',
            variant: SharelyButtonVariant.ink,
            leadingIcon: LucideIcons.plus,
            onPressed: onPairNew,
          ),
        ),
      ],
    );
  }
}
