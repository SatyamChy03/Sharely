import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/features/laptop/laptop_devices_view.dart';
import 'package:sharely/features/laptop/laptop_history_view.dart';
import 'package:sharely/features/laptop/widgets/activity_panel.dart';
import 'package:sharely/features/laptop/widgets/drop_zone_card.dart';
import 'package:sharely/features/laptop/widgets/laptop_nav_rail.dart';
import 'package:sharely/features/laptop/widgets/phone_chip.dart';
import 'package:sharely/features/laptop/widgets/phone_send_card.dart';
import 'package:sharely/features/laptop/widgets/quick_text_bar.dart';
import 'package:sharely/features/pairing/state/laptop_pairing_controller.dart';
import 'package:sharely/features/pairing/state/paired_devices.dart';
import 'package:sharely/features/transfer/state/connected_phones.dart';
import 'package:sharely/features/transfer/state/phone_send_controller.dart';
import 'package:sharely/features/transfer/state/quick_text_result.dart';
import 'package:sharely/features/transfer/state/send_state.dart';
import 'package:sharely/features/transfer/widgets/incoming_transfers_overlay.dart';

/// Laptop shell once paired: Home, History and Devices beside one rail.
class LaptopHomeScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<LaptopHomeScreen> createState() => _LaptopHomeScreenState();
}

class _LaptopHomeScreenState extends ConsumerState<LaptopHomeScreen> {
  static const _wideLayoutMinWidth = 900.0;

  LaptopSection _section = LaptopSection.home;

  void _showSection(LaptopSection section) {
    // A pairing code must not stay redeemable after its QR is hidden.
    ref.read(laptopPairingProvider.notifier).stopPairing();
    setState(() => _section = section);
  }

  @override
  Widget build(BuildContext context) {
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
                selected: _section,
                onSelect: _showSection,
                onComingSoon: _explainComingSoon,
              ),
              Expanded(
                child: switch (_section) {
                  LaptopSection.history => const LaptopHistoryView(),
                  LaptopSection.devices => const LaptopDevicesView(),
                  LaptopSection.home => LayoutBuilder(
                    builder: (context, constraints) => _buildHome(
                      phoneName: phone?.deviceName ?? 'your phone',
                      isConnected: isConnected,
                      isWide: constraints.maxWidth >= _wideLayoutMinWidth,
                    ),
                  ),
                },
              ),
            ],
          ),
          const IncomingTransfersOverlay(),
        ],
      ),
    );
  }

  Widget _buildHome({
    required String phoneName,
    required bool isConnected,
    required bool isWide,
  }) {
    final sendColumn = _SendColumn(
      phoneName: phoneName,
      isConnected: isConnected,
    );
    final activity = ActivityPanel(
      onSeeAll: () => _showSection(LaptopSection.history),
    );
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
      child: isWide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 24,
              children: [
                Expanded(flex: 2, child: sendColumn),
                Expanded(child: activity),
              ],
            )
          : Column(spacing: 24, children: [sendColumn, activity]),
    );
  }

  void _explainComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature arrives in a later update.')),
    );
  }
}

class _SendColumn extends ConsumerWidget {
  const new({required this.phoneName, required this.isConnected});

  final String phoneName;
  final bool isConnected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final send = ref.watch(phoneSendProvider);
    final controller = ref.read(phoneSendProvider.notifier);
    final canSend = isConnected && send is SendIdle;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 18,
      children: [
        _SendHeading(phoneName: phoneName, isConnected: isConnected),
        DropZoneCard(
          phoneName: phoneName,
          onChooseFiles: canSend ? controller.pickAndSendFiles : null,
          onChooseFolder: canSend ? controller.pickAndSendFolder : null,
          onDropPaths: canSend ? controller.sendPaths : null,
        ),
        if (send is SendWithFiles)
          PhoneSendCard(
            send: send,
            phoneName: phoneName,
            onCancel: controller.cancel,
            onDismiss: controller.dismiss,
          ),
        QuickTextBar(
          onSend: isConnected ? (text) => _sendText(context, ref, text) : null,
        ),
        if (!isConnected)
          Text(
            'Open Sharely on $phoneName, on the same Wi-Fi, to send to it.',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: SharelyColors.slate),
          ),
      ],
    );
  }

  bool _sendText(BuildContext context, WidgetRef ref, String text) {
    final result = ref.read(phoneSendProvider.notifier).sendText(text);
    final notice = switch (result) {
      QuickTextResult.sent => 'Sent to $phoneName.',
      QuickTextResult.empty => 'Type or paste something to send first.',
      QuickTextResult.tooLong =>
        'That is too long to send as text. Save it as a file and send that.',
      QuickTextResult.notConnected =>
        "$phoneName isn't connected. Open Sharely on it and try again.",
    };
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(notice)));
    return result == QuickTextResult.sent;
  }
}

class _SendHeading extends StatelessWidget {
  const new({required this.phoneName, required this.isConnected});

  final String phoneName;
  final bool isConnected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 12,
      children: [
        Text(
          'Send to phone',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.2,
          ),
        ),
        PhoneChip(phoneName: phoneName, isConnected: isConnected),
      ],
    );
  }
}
