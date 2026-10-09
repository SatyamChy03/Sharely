import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sharely/app/routes.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/design/typography.dart';
import 'package:sharely/design/widgets/icon_square_button.dart';
import 'package:sharely/design/widgets/sharely_wordmark.dart';
import 'package:sharely/features/pairing/state/laptop_pairing_controller.dart';
import 'package:sharely/features/pairing/state/laptop_pairing_state.dart';
import 'package:sharely/features/pairing/state/paired_devices.dart';
import 'package:sharely/features/pairing/widgets/firewall_hint.dart';
import 'package:sharely/features/pairing/widgets/laptop_connected_view.dart';
import 'package:sharely/features/pairing/widgets/laptop_pairing_intro.dart';
import 'package:sharely/features/pairing/widgets/laptop_status_card.dart';
import 'package:sharely/features/pairing/widgets/pairing_qr_card.dart';
import 'package:sharely/features/transfer/widgets/incoming_transfers_overlay.dart';

/// Laptop pairing (D02 and D04): shows the QR code until a phone pairs.
class LaptopPairingScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pairing = ref.watch(laptopPairingProvider);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: Stack(
          children: [
            Column(
              children: [
                _TopBar(isWaiting: pairing.value is LaptopWaitingForPhone),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: SharelySpacing.xxl,
                        vertical: SharelySpacing.xl,
                      ),
                      child: AnimatedSwitcher(
                        duration: SharelyMotion.medium,
                        child: _PairingBody(pairing: pairing),
                      ),
                    ),
                  ),
                ),
                const _Footer(),
              ],
            ),
            const IncomingTransfersOverlay(),
          ],
        ),
      ),
    );
  }
}

class _PairingBody extends ConsumerWidget {
  const new({required this.pairing});

  final AsyncValue<LaptopPairingState> pairing;

  static const _wideLayoutMinWidth = 820.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (pairing) {
      AsyncData(value: LaptopWaitingForPhone() && final waiting) =>
        _buildWaiting(context, waiting),
      AsyncData(value: LaptopPairedWithPhone(:final phone)) =>
        LaptopConnectedView(
          phone: phone,
          onStartSending: () => context.go(AppRoutes.laptopHome),
          onPairAnother: ref.read(laptopPairingProvider.notifier).showNewCode,
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
        message: 'Starting a pairing session.',
      ),
    };
  }

  Widget _buildWaiting(BuildContext context, LaptopWaitingForPhone waiting) {
    final intro = LaptopPairingIntro(waiting: waiting);
    final code = PairingQrCard(waiting: waiting);
    if (MediaQuery.sizeOf(context).width < _wideLayoutMinWidth) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        spacing: SharelySpacing.xxl,
        children: [code, intro],
      );
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 900),
      child: Row(
        spacing: 64,
        children: [
          Expanded(child: intro),
          code,
        ],
      ),
    );
  }
}

class _TopBar extends ConsumerWidget {
  const new({required this.isWaiting});

  final bool isWaiting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devices = ref.watch(pairedDevicesProvider).value ?? const [];
    return SizedBox(
      height: 64,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Row(
          spacing: SharelySpacing.lg,
          children: [
            const SharelyWordmark(markSize: 24),
            if (isWaiting)
              Text(
                'PAIR A PHONE',
                style: sharelyMonoStyle(
                  size: 12,
                  color: SharelyColors.textSecondary,
                  tracking: 1,
                ),
              ),
            const Spacer(),
            // Opened to pair another phone: the way back to the laptop home.
            if (devices.isNotEmpty)
              IconSquareButton(
                icon: LucideIcons.x,
                tooltip: 'Back to Home',
                size: 40,
                background: Colors.transparent,
                color: SharelyColors.textSecondary,
                onPressed: () {
                  ref.read(laptopPairingProvider.notifier).stopPairing();
                  context.go(AppRoutes.laptopHome);
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: SharelySpacing.xl,
        runSpacing: SharelySpacing.sm,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            spacing: SharelySpacing.sm,
            children: [
              const Icon(
                LucideIcons.wifi,
                size: 15,
                color: SharelyColors.textSecondary,
              ),
              Flexible(
                child: Text(
                  'Both devices need to be on the same Wi-Fi. Files go '
                  'directly between them.',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: SharelyColors.textSecondary),
                ),
              ),
            ],
          ),
          const FirewallHint(),
        ],
      ),
    );
  }
}
