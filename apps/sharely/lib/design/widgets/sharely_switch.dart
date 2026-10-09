import 'package:flutter/material.dart';
import 'package:sharely/design/tokens.dart';

/// The design's toggle: a cyan track with a dark knob when on.
class SharelySwitch extends StatelessWidget {
  const new({
    required this.value,
    required this.onChanged,
    required this.label,
    super.key,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    final handler = onChanged;
    return Semantics(
      label: label,
      toggled: value,
      child: InkWell(
        onTap: handler == null ? null : () => handler(!value),
        borderRadius: const BorderRadius.all(SharelyRadii.pill),
        child: SizedBox(
          width: 48,
          height: SharelySizes.minTouchTarget,
          child: Center(
            child: AnimatedContainer(
              duration: SharelyMotion.fast,
              width: 44,
              height: 26,
              padding: const EdgeInsets.all(3),
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              decoration: BoxDecoration(
                color: value ? SharelyColors.primary : SharelyColors.lineStrong,
                borderRadius: const BorderRadius.all(SharelyRadii.pill),
              ),
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: value
                      ? SharelyColors.onPrimary
                      : SharelyColors.textSecondary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
