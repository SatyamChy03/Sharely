import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/design/typography.dart';
import 'package:sharely/design/widgets/sharely_logo.dart';
import 'package:sharely/features/pairing/state/laptop_pairing_state.dart';
import 'package:sharely/features/pairing/widgets/expiry_countdown.dart';

/// White card with the pairing QR code and the typed-code fallback.
class PairingQrCard extends StatelessWidget {
  const new({required this.waiting, super.key});

  final LaptopWaitingForPhone waiting;

  static const _qrSize = 260.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(SharelySpacing.xxl),
      decoration: const BoxDecoration(
        color: SharelyColors.surface,
        borderRadius: BorderRadius.all(SharelyRadii.panel),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 22,
        children: [
          Semantics(
            label: 'Pairing QR code. Scan it with Sharely on your phone.',
            image: true,
            child: SizedBox.square(
              dimension: _qrSize,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PrettyQrView.data(
                    key: ValueKey(waiting.invite.token),
                    data: waiting.invite.toUriString(),
                    // High error correction keeps it readable under the logo.
                    errorCorrectLevel: QrErrorCorrectLevel.H,
                    decoration: const PrettyQrDecoration(
                      shape: PrettyQrSmoothSymbol(color: SharelyColors.ink),
                    ),
                  ).animate(key: ValueKey(waiting.invite.token)).fadeIn(),
                  const _LogoBadge(),
                ],
              ),
            ),
          ),
          const _WaitingIndicator(),
          const Divider(color: SharelyColors.mist, height: 1),
          _CodeFallback(waiting: waiting),
        ],
      ),
    );
  }
}

class _LogoBadge extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: const BoxDecoration(
        color: SharelyColors.ink,
        borderRadius: BorderRadius.all(Radius.circular(14)),
      ),
      alignment: Alignment.center,
      child: const SharelyLogoMark(size: 34),
    );
  }
}

class _WaitingIndicator extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final pulse = Container(
      width: 10,
      height: 10,
      decoration: const BoxDecoration(
        color: SharelyColors.accent,
        shape: BoxShape.circle,
      ),
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      spacing: 10,
      children: [
        pulse
            .animate(onPlay: (controller) => controller.repeat(reverse: true))
            .scaleXY(begin: 0.7, end: 1.3, duration: 900.ms)
            .fade(begin: 0.5, end: 1),
        Text(
          'Waiting for your phone…',
          style: Theme.of(context).textTheme.titleSmall
              ?.copyWith(color: SharelyColors.ink),
        ),
      ],
    );
  }
}

class _CodeFallback extends StatelessWidget {
  const new({required this.waiting});

  final LaptopWaitingForPhone waiting;

  @override
  Widget build(BuildContext context) {
    final code = waiting.code;
    final spacedCode = '${code.substring(0, 3)} ${code.substring(3)}';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Or type this code',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: SharelyColors.slate),
            ),
            SelectableText(
              spacedCode,
              style: sharelyMonoStyle(
                size: 30,
                color: SharelyColors.ink,
              ).copyWith(letterSpacing: 4),
            ),
          ],
        ),
        ExpiryCountdown(expiresAt: waiting.expiresAt),
      ],
    );
  }
}
