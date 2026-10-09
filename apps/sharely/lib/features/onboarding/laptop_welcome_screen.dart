import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:sharely/app/routes.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/features/onboarding/widgets/laptop_welcome_pitch.dart';
import 'package:sharely/features/onboarding/widgets/laptop_welcome_steps.dart';

/// First screen on a laptop with no paired phone (D01 of the v3 design).
class LaptopWelcomeScreen extends StatelessWidget {
  const new({super.key});

  static const _splitLayoutMinWidth = 960.0;

  @override
  Widget build(BuildContext context) {
    final steps = LaptopWelcomeSteps(
      onPairPhone: () => context.go(AppRoutes.laptopPairing),
    );
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < _splitLayoutMinWidth) {
              return _buildStacked(steps);
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Expanded(
                  flex: 13,
                  child: LaptopWelcomePitch(isFillingHeight: true),
                ),
                Expanded(
                  flex: 11,
                  child: Center(
                    child: SingleChildScrollView(
                      padding: _panelPadding,
                      child: steps,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  static const _panelPadding = EdgeInsets.symmetric(
    horizontal: 56,
    vertical: SharelySpacing.huge,
  );

  Widget _buildStacked(Widget steps) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const LaptopWelcomePitch(isFillingHeight: false),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: SharelySpacing.xxl,
              vertical: SharelySpacing.huge,
            ),
            child: Center(child: steps),
          ),
        ],
      ),
    );
  }
}
