import 'package:flutter/material.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/design/typography.dart';

/// "2/3" style progress for the get-started flow on light screens.
class StepProgress extends StatelessWidget {
  const new({required this.currentStep, super.key, this.totalSteps = 3});

  final int currentStep;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Step $currentStep of $totalSteps',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 6,
        children: [
          for (var step = 1; step <= totalSteps; step++)
            AnimatedContainer(
              duration: SharelyMotion.medium,
              curve: SharelyMotion.standard,
              width: 22,
              height: 6,
              decoration: BoxDecoration(
                color: step <= currentStep
                    ? SharelyColors.ink
                    : SharelyColors.mist,
                borderRadius: const BorderRadius.all(Radius.circular(3)),
              ),
            ),
          const SizedBox(width: 2),
          Text(
            '$currentStep/$totalSteps',
            style: sharelyMonoStyle(size: 13, color: SharelyColors.ink),
          ),
        ],
      ),
    );
  }
}
