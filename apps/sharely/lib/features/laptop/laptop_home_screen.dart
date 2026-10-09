import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sharely/features/laptop/laptop_activity_view.dart';
import 'package:sharely/features/laptop/laptop_devices_view.dart';
import 'package:sharely/features/laptop/laptop_home_view.dart';
import 'package:sharely/features/laptop/laptop_receive_view.dart';
import 'package:sharely/features/laptop/laptop_send_view.dart';
import 'package:sharely/features/laptop/laptop_settings_view.dart';
import 'package:sharely/features/laptop/widgets/laptop_sidebar.dart';
import 'package:sharely/features/pairing/state/laptop_pairing_controller.dart';
import 'package:sharely/features/pairing/state/local_identity.dart';
import 'package:sharely/features/pairing/state/paired_devices.dart';
import 'package:sharely/features/transfer/state/connected_phones.dart';
import 'package:sharely/features/transfer/state/phone_send_controller.dart';
import 'package:sharely/features/transfer/state/send_state.dart';
import 'package:sharely/features/transfer/widgets/incoming_transfers_overlay.dart';
import 'package:sharely_core/sharely_core.dart';

/// Laptop shell once paired: six sections beside one sidebar.
class LaptopHomeScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<LaptopHomeScreen> createState() => _LaptopHomeScreenState();
}

class _LaptopHomeScreenState extends ConsumerState<LaptopHomeScreen> {
  static const _sidebarMinWindowWidth = 720.0;

  LaptopSection _section = LaptopSection.home;

  void _showSection(LaptopSection section) =>
      setState(() => _section = section);

  @override
  Widget build(BuildContext context) {
    // Watching keeps the laptop's server running while this screen shows.
    ref.watch(laptopPairingProvider);
    // A send that starts anywhere is followed on the Send page.
    ref.listen(phoneSendProvider, (previous, next) {
      if (previous is SendIdle && next is! SendIdle) {
        _showSection(LaptopSection.send);
      }
    });
    final devices = ref.watch(pairedDevicesProvider).value ?? const [];
    final connectedIds = ref.watch(connectedPhonesProvider);
    final phone = devices.lastOrNull;
    final isConnected = phone != null && connectedIds.contains(phone.deviceId);
    final deviceName = ref.watch(localHelloProvider).value?.deviceName ?? '';
    final page = _buildPage(
      devices: devices,
      connectedIds: connectedIds,
      deviceName: deviceName,
    );
    final hasSidebar =
        MediaQuery.sizeOf(context).width >= _sidebarMinWindowWidth;
    return Scaffold(
      body: Stack(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LaptopSidebar(
                selected: _section,
                onSelect: _showSection,
                deviceName: deviceName,
                isConnected: isConnected,
                isCompact: !hasSidebar,
              ),
              Expanded(child: page),
            ],
          ),
          const IncomingTransfersOverlay(),
        ],
      ),
    );
  }

  Widget _buildPage({
    required List<PairedDevice> devices,
    required Set<String> connectedIds,
    required String deviceName,
  }) {
    final phone = devices.lastOrNull;
    final phoneName = phone?.deviceName ?? 'your phone';
    final isConnected = phone != null && connectedIds.contains(phone.deviceId);
    return switch (_section) {
      LaptopSection.home => LaptopHomeView(
        phoneName: phoneName,
        isConnected: isConnected,
        onChangeDevice: () => _showSection(LaptopSection.devices),
        onViewAll: () => _showSection(LaptopSection.activity),
      ),
      LaptopSection.send => LaptopSendView(
        phoneName: phoneName,
        isConnected: isConnected,
      ),
      LaptopSection.receive => LaptopReceiveView(
        connectedCount: devices
            .where((device) => connectedIds.contains(device.deviceId))
            .length,
      ),
      LaptopSection.activity => const LaptopActivityView(),
      LaptopSection.devices => LaptopDevicesView(
        deviceName: deviceName,
        onSendTo: () => _showSection(LaptopSection.home),
      ),
      LaptopSection.settings => const LaptopSettingsView(),
    };
  }
}
