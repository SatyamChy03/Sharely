import 'package:flutter/material.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/design/widgets/sharely_button.dart';

/// Decline and Accept, side by side; Accept is the screen's one accent.
class IncomingOfferActions extends StatelessWidget {
  const new({required this.onAccept, required this.onDecline, super.key});

  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: SharelySpacing.sm,
      children: [
        Expanded(
          child: SharelyButton(
            label: 'Decline',
            variant: SharelyButtonVariant.outline,
            onPressed: onDecline,
          ),
        ),
        Expanded(
          child: SharelyButton(label: 'Accept', onPressed: onAccept),
        ),
      ],
    );
  }
}
