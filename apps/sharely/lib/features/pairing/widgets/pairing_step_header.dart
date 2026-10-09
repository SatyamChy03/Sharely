import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/design/typography.dart';
import 'package:sharely/design/widgets/icon_square_button.dart';

/// Top of each pairing step: an optional back button and "STEP 1 OF 2".
class PairingStepHeader extends StatelessWidget {
  const new({required this.currentStep, super.key, this.onBack});

  final int currentStep;
  final VoidCallback? onBack;

  static const _totalSteps = 2;

  @override
  Widget build(BuildContext context) {
    final back = onBack;
    return SizedBox(
      height: SharelySizes.minTouchTarget,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (back != null)
            Align(
              alignment: Alignment.centerLeft,
              child: IconSquareButton(
                icon: LucideIcons.chevronLeft,
                tooltip: 'Back',
                onPressed: back,
              ),
            ),
          Text(
            'STEP $currentStep OF $_totalSteps',
            style: sharelyMonoStyle(
              size: 12,
              color: SharelyColors.textSecondary,
              tracking: 1,
            ),
          ),
        ],
      ),
    );
  }
}
