import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:sharely/design/theme.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/design/widgets/sharely_wordmark.dart';
import 'package:sharely/features/pairing/state/laptop_pairing_controller.dart';
import 'package:sharely/features/pairing/state/laptop_pairing_state.dart';
import 'package:sharely/features/pairing/widgets/laptop_pairing_intro.dart';
import 'package:sharely/features/pairing/widgets/laptop_status_card.dart';
import 'package:sharely/features/pairing/widgets/pairing_qr_card.dart';
import 'package:sharely/features/transfer/state/has_received_file.dart';
import 'package:sharely/features/transfer/widgets/incoming_transfers_overlay.dart';

/// Laptop get-started screen: shows the QR code until a phone pairs.
class LaptopPairingScreen extends ConsumerWidget {
  const new({super.key});

  static const _wideLayoutMinWidth = 860.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pairing = ref.watch(laptopPairingProvider);
    final isPaired = pairing.value is LaptopPairedWithPhone;
    final hasReceivedFile = ref.watch(hasReceivedFileProvider);
    return Theme(
      data: SharelyTheme.dark(),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          body: Stack(
            children: [
              _buildScrollingBody(
                pairing: pairing,
                isPaired: isPaired,
                hasReceivedFile: hasReceivedFile,
              ),
              const IncomingTransfersOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScrollingBody({
    required AsyncValue<LaptopPairingState> pairing,
    required bool isPaired,
    required bool hasReceivedFile,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: LayoutBuilder(
            builder: (context, constraints) => _buildLayout(
              isWide: constraints.maxWidth >= _wideLayoutMinWidth,
              intro: LaptopPairingIntro(
                isPaired: isPaired,
                hasReceivedFile: hasReceivedFile,
              ),
              panel: _PairingPanel(pairing: pairing),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLayout({
    required bool isWide,
    required Widget intro,
    required Widget panel,
  }) {
    final body = isWide
        ? Row(
            spacing: 48,
            children: [
              Expanded(child: intro),
              Expanded(child: panel),
            ],
          )
        : Column(spacing: 32, children: [intro, panel]);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [const SharelyWordmark(), const Gap(40), body],
    );
  }
}

class _PairingPanel extends ConsumerWidget {
  const new({required this.pairing});

  final AsyncValue<LaptopPairingState> pairing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final card = switch (pairing) {
      AsyncData(value: LaptopWaitingForPhone() && final waiting) =>
        PairingQrCard(waiting: waiting),
      AsyncData(value: LaptopPairedWithPhone(:final phone)) => LaptopStatusCard(
        icon: LaptopStatusCard.pairedIcon,
        title: 'Paired with ${phone.deviceName}',
        message: 'Your phone and this laptop now trust each other.',
        actionLabel: 'Pair another phone',
        onAction: ref.read(laptopPairingProvider.notifier).showNewCode,
      ),
      AsyncData(value: LaptopNotOnNetwork()) => LaptopStatusCard(
        icon: LaptopStatusCard.offlineIcon,
        title: 'Connect to Wi-Fi',
        message: 'Join the same Wi-Fi network as your phone, then try again.',
        actionLabel: 'Try again',
        onAction: () => ref.invalidate(lanAddressProvider),
      ),
      AsyncError() => LaptopStatusCard(
        icon: LaptopStatusCard.errorIcon,
        title: "Couldn't start pairing",
        message:
            'Another app may be blocking the network. Restart Sharely '
            'and allow it through your firewall if asked.',
        actionLabel: 'Try again',
        onAction: () => ref.invalidate(laptopPairingProvider),
      ),
      _ => const LaptopStatusCard(
        title: 'Getting ready…',
        message: 'Starting a secure pairing session.',
      ),
    };
    return AnimatedSwitcher(duration: SharelyMotion.medium, child: card);
  }
}
