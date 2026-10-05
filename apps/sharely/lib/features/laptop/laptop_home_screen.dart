import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sharely/app/routes.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/features/laptop/widgets/activity_panel.dart';
import 'package:sharely/features/laptop/widgets/drop_zone_card.dart';
import 'package:sharely/features/laptop/widgets/laptop_nav_rail.dart';
import 'package:sharely/features/laptop/widgets/phone_chip.dart';
import 'package:sharely/features/laptop/widgets/quick_text_bar.dart';
import 'package:sharely/features/pairing/state/laptop_pairing_controller.dart';
import 'package:sharely/features/pairing/state/paired_devices.dart';
import 'package:sharely/features/transfer/state/connected_phones.dart';
import 'package:sharely/features/transfer/widgets/incoming_transfers_overlay.dart';

/// Laptop home once paired: send to the phone, and see what arrived.
class LaptopHomeScreen extends ConsumerWidget {
  const new({super.key});

  static const _wideLayoutMinWidth = 900.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watching keeps the laptop's server running while this screen shows.
    ref.watch(laptopPairingProvider);
    final devices = ref.watch(pairedDevicesProvider).value ?? const [];
    final phone = devices.lastOrNull;
    final isConnected =
        phone != null &&
        ref.watch(connectedPhonesProvider).contains(phone.deviceId);
    return Scaffold(
      body: Stack(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LaptopNavRail(
                onDevices: () => _openPairing(context, ref),
                onComingSoon: (feature) => _explainComingSoon(context, feature),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) => _buildMain(
                    phoneName: phone?.deviceName ?? 'your phone',
                    isConnected: isConnected,
                    isWide: constraints.maxWidth >= _wideLayoutMinWidth,
                  ),
                ),
              ),
            ],
          ),
          const IncomingTransfersOverlay(),
        ],
      ),
    );
  }

  Widget _buildMain({
    required String phoneName,
    required bool isConnected,
    required bool isWide,
  }) {
    final sendColumn = _SendColumn(
      phoneName: phoneName,
      isConnected: isConnected,
    );
    const activity = ActivityPanel();
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
      child: isWide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 24,
              children: [
                Expanded(flex: 2, child: sendColumn),
                const Expanded(child: activity),
              ],
            )
          : Column(spacing: 24, children: [sendColumn, activity]),
    );
  }

  void _openPairing(BuildContext context, WidgetRef ref) {
    ref.read(laptopPairingProvider.notifier).showNewCode();
    context.go(AppRoutes.laptopPairing);
  }

  void _explainComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature arrives in a later update.')),
    );
  }
}

class _SendColumn extends StatelessWidget {
  const new({required this.phoneName, required this.isConnected});

  final String phoneName;
  final bool isConnected;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 18,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: [
            Text(
              'Send to phone',
              style: textTheme.headlineMedium?.copyWith(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.2,
              ),
            ),
            PhoneChip(phoneName: phoneName, isConnected: isConnected),
          ],
        ),
        DropZoneCard(
          phoneName: phoneName,
          onChooseFiles: null,
          onChooseFolder: null,
        ),
        const QuickTextBar(onSend: null),
        Text(
          'Sending from this laptop to your phone arrives in the next update. '
          'Your phone can already send files here.',
          style: textTheme.bodySmall?.copyWith(color: SharelyColors.slate),
        ),
      ],
    );
  }
}
