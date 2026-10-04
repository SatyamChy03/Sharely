import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sharely/design/tokens.dart';

enum SharelyButtonVariant { accent, ink, outline }

/// Full-width primary action. Accent on dark screens, Ink on light screens.
class SharelyButton extends StatefulWidget {
  const new({
    required this.label,
    required this.onPressed,
    super.key,
    this.variant = SharelyButtonVariant.accent,
    this.trailingIcon,
  });

  final String label;
  final VoidCallback? onPressed;
  final SharelyButtonVariant variant;
  final IconData? trailingIcon;

  @override
  State<SharelyButton> createState() => _SharelyButtonState();
}

class _SharelyButtonState extends State<SharelyButton> {
  bool _isPressed = false;

  void _setPressed({required bool isPressed}) {
    if (widget.onPressed == null || _isPressed == isPressed) return;
    setState(() => _isPressed = isPressed);
  }

  void _handlePressed() {
    unawaited(HapticFeedback.lightImpact());
    widget.onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _setPressed(isPressed: true),
      onPointerUp: (_) => _setPressed(isPressed: false),
      onPointerCancel: (_) => _setPressed(isPressed: false),
      child: AnimatedScale(
        scale: _isPressed ? 0.97 : 1,
        duration: SharelyMotion.fast,
        curve: SharelyMotion.standard,
        child: SizedBox(
          width: double.infinity,
          height: SharelySizes.buttonHeight,
          child: TextButton(
            onPressed: widget.onPressed == null ? null : _handlePressed,
            style: _buttonStyle(context),
            child: _ButtonContent(widget.label, widget.trailingIcon),
          ),
        ),
      ),
    );
  }

  ButtonStyle _buttonStyle(BuildContext context) {
    final (background, foreground, border) = switch (widget.variant) {
      SharelyButtonVariant.accent => (
        SharelyColors.accent,
        SharelyColors.onAccent,
        null,
      ),
      SharelyButtonVariant.ink => (
        SharelyColors.ink,
        SharelyColors.surface,
        null,
      ),
      SharelyButtonVariant.outline => (
        Colors.transparent,
        Theme.of(context).colorScheme.onSurface,
        BorderSide(color: Theme.of(context).colorScheme.outline, width: 1.5),
      ),
    };
    return TextButton.styleFrom(
      backgroundColor: background,
      foregroundColor: foreground,
      textStyle: Theme.of(context).textTheme.labelLarge,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(SharelyRadii.button),
        side: border ?? BorderSide.none,
      ),
    );
  }
}

class _ButtonContent extends StatelessWidget {
  const new(this.label, this.trailingIcon);

  final String label;
  final IconData? trailingIcon;

  @override
  Widget build(BuildContext context) {
    final icon = trailingIcon;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      spacing: SharelySpacing.sm,
      children: [Text(label), if (icon != null) Icon(icon, size: 20)],
    );
  }
}
