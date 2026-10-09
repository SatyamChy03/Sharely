import 'package:flutter/material.dart';
import 'package:sharely/design/tokens.dart';

/// Primary is the one main action on a view; the rest support it.
enum SharelyButtonVariant { primary, secondary, ghost, danger }

/// The app's button: 10 px corners, 36 to 52 px tall, full width by default.
class SharelyButton extends StatelessWidget {
  const new({
    required this.label,
    required this.onPressed,
    super.key,
    this.variant = SharelyButtonVariant.primary,
    this.height = SharelySizes.buttonLarge,
    this.isExpanded = true,
    this.trailingIcon,
    this.leadingIcon,
  });

  final String label;
  final VoidCallback? onPressed;
  final SharelyButtonVariant variant;
  final double height;
  final bool isExpanded;
  final IconData? trailingIcon;
  final IconData? leadingIcon;

  @override
  Widget build(BuildContext context) {
    final button = TextButton(
      onPressed: onPressed,
      style: _buttonStyle(context),
      child: _ButtonContent(
        label,
        iconSize: height >= SharelySizes.buttonMedium ? 18 : 16,
        trailingIcon: trailingIcon,
        leadingIcon: leadingIcon,
      ),
    );
    return SizedBox(
      width: isExpanded ? double.infinity : null,
      height: height,
      child: button,
    );
  }

  ButtonStyle _buttonStyle(BuildContext context) {
    final (background, hover, foreground, border) = _colors();
    final isPrimary = variant == SharelyButtonVariant.primary;
    final isLarge = height > SharelySizes.buttonMedium;
    return ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return isPrimary ? SharelyColors.elevated : background;
        }
        final isActive =
            states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.pressed);
        return isActive ? hover : background;
      }),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        return states.contains(WidgetState.disabled)
            ? SharelyColors.textSecondary
            : foreground;
      }),
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      minimumSize: const WidgetStatePropertyAll(Size.zero),
      padding: WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: isLarge ? 20 : 14),
      ),
      textStyle: WidgetStatePropertyAll(
        Theme.of(context).textTheme.labelLarge?.copyWith(
          fontSize: isLarge ? 16 : (height >= 40 ? 15 : 13),
          fontWeight: isPrimary ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(SharelyRadii.button),
          side: border == null ? BorderSide.none : BorderSide(color: border),
        ),
      ),
    );
  }

  (Color, Color, Color, Color?) _colors() => switch (variant) {
    SharelyButtonVariant.primary => (
      SharelyColors.primary,
      SharelyColors.primaryHover,
      SharelyColors.onPrimary,
      null,
    ),
    SharelyButtonVariant.secondary => (
      SharelyColors.elevated,
      SharelyColors.secondaryHover,
      SharelyColors.text,
      SharelyColors.lineStrong,
    ),
    SharelyButtonVariant.ghost => (
      Colors.transparent,
      SharelyColors.elevated,
      SharelyColors.textSecondary,
      null,
    ),
    SharelyButtonVariant.danger => (
      SharelyColors.dangerSurface,
      SharelyColors.dangerSurface,
      SharelyColors.dangerText,
      SharelyColors.dangerLine,
    ),
  };
}

class _ButtonContent extends StatelessWidget {
  const new(
    this.label, {
    required this.iconSize,
    this.trailingIcon,
    this.leadingIcon,
  });

  final String label;
  final double iconSize;
  final IconData? trailingIcon;
  final IconData? leadingIcon;

  @override
  Widget build(BuildContext context) {
    final leading = leadingIcon;
    final trailing = trailingIcon;
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      spacing: SharelySpacing.sm,
      children: [
        if (leading != null) Icon(leading, size: iconSize),
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
        if (trailing != null) Icon(trailing, size: iconSize),
      ],
    );
  }
}
