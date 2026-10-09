import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/design/widgets/flow_dots.dart';
import 'package:sharely/design/widgets/sharely_logo.dart';
import 'package:sharely/features/pairing/state/laptop_pairing_state.dart';

/// The pairing QR code on a light card, so any phone camera can read it.
class PairingQrCard extends StatelessWidget {
  const new({required this.waiting, super.key});

  final LaptopWaitingForPhone waiting;

  static const _cardSize = 320.0;

  @override
  Widget build(BuildContext context) {
    final code = PrettyQrView.data(
      key: ValueKey(waiting.invite.token),
      data: waiting.invite.toUriString(),
      // High error correction keeps it readable under the logo.
      errorCorrectLevel: QrErrorCorrectLevel.H,
      decoration: const PrettyQrDecoration(
        shape: PrettyQrSmoothSymbol(color: SharelyColors.background),
      ),
    ).animate(key: ValueKey(waiting.invite.token)).fadeIn();
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 18,
      children: [
        Semantics(
          label: 'Pairing QR code. Scan it with Sharely on your phone.',
          image: true,
          child: Container(
            width: _cardSize,
            height: _cardSize,
            padding: const EdgeInsets.all(22),
            decoration: const BoxDecoration(
              color: SharelyColors.text,
              borderRadius: BorderRadius.all(SharelyRadii.card),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [code, const _LogoBadge()],
            ),
          ),
        ),
        const _WaitingIndicator(),
      ],
    );
  }
}

class _LogoBadge extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: SharelyColors.text,
        borderRadius: BorderRadius.all(SharelyRadii.tile),
      ),
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: SharelyColors.background,
          borderRadius: BorderRadius.all(SharelyRadii.button),
        ),
        child: const SharelyLogoMark(size: 30),
      ),
    );
  }
}

class _WaitingIndicator extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 10,
      children: [
        const FlowDots(count: 2, dotSize: 7),
        Text(
          'Waiting for a scan…',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w400,
            color: SharelyColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
