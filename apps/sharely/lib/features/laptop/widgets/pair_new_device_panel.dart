import 'package:flutter/material.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/design/widgets/sharely_button.dart';
import 'package:sharely/features/pairing/state/laptop_pairing_state.dart';
import 'package:sharely/features/pairing/widgets/pairing_qr_card.dart';

/// The QR code for one more device, with the steps and a way to stop.
class PairNewDevicePanel extends StatelessWidget {
  const new({required this.waiting, required this.onCancel, super.key});

  final LaptopWaitingForPhone waiting;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 14,
      children: [
        Text('Pair a new device', style: textTheme.titleLarge),
        Text(
          'Open Sharely on the phone, tap Scan, and point it at this code. '
          'Both devices need to be on the same Wi-Fi.',
          style: textTheme.bodyMedium?.copyWith(color: SharelyColors.slate),
        ),
        PairingQrCard(waiting: waiting),
        SharelyButton(
          label: 'Cancel',
          variant: SharelyButtonVariant.outline,
          onPressed: onCancel,
        ),
      ],
    );
  }
}
