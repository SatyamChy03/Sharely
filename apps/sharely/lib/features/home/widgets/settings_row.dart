import 'package:flutter/material.dart';
import 'package:sharely/design/tokens.dart';

/// One settings line: an icon, a label, and a value or control at the end.
class SettingsRow extends StatelessWidget {
  const new({
    required this.icon,
    required this.label,
    super.key,
    this.value,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String label;

  /// Read-only text at the end, such as "Dark".
  final String? value;

  /// A control at the end, such as a switch; shown after [value].
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final shownValue = value;
    final control = trailing;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            spacing: SharelySpacing.md,
            children: [
              Icon(icon, size: 18, color: SharelyColors.textSecondary),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium,
                ),
              ),
              if (shownValue != null)
                Text(
                  shownValue,
                  style: textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w400,
                    color: SharelyColors.textSecondary,
                  ),
                ),
              ?control,
            ],
          ),
        ),
      ),
    );
  }
}
