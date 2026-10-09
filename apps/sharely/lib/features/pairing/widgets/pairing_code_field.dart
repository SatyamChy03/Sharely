import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/design/typography.dart';

/// Six mono digit boxes over one hidden field, as the laptop shows the code.
class PairingCodeField extends StatefulWidget {
  const new({
    required this.onChanged,
    super.key,
    this.isEnabled = true,
    this.hasError = false,
  });

  final ValueChanged<String> onChanged;
  final bool isEnabled;
  final bool hasError;

  static const length = 6;

  @override
  State<PairingCodeField> createState() => _PairingCodeFieldState();
}

class _PairingCodeFieldState extends State<PairingCodeField> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Six-digit pairing code',
      child: Stack(
        children: [
          ListenableBuilder(
            listenable: Listenable.merge([_controller, _focusNode]),
            builder: (context, _) => _DigitBoxes(
              digits: _controller.text,
              hasFocus: _focusNode.hasFocus,
              hasError: widget.hasError,
            ),
          ),
          Positioned.fill(
            child: Opacity(
              // Invisible but real, so the keyboard, paste and autofill work.
              opacity: 0,
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                enabled: widget.isEnabled,
                autofocus: true,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(PairingCodeField.length),
                ],
                showCursor: false,
                onChanged: widget.onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DigitBoxes extends StatelessWidget {
  const new({
    required this.digits,
    required this.hasFocus,
    required this.hasError,
  });

  final String digits;
  final bool hasFocus;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: SharelySpacing.sm,
      children: [
        for (var index = 0; index < PairingCodeField.length; index++) ...[
          // The laptop shows the code as two groups of three.
          if (index == PairingCodeField.length ~/ 2)
            Container(width: 12, height: 2, color: SharelyColors.lineStrong),
          Expanded(child: _box(index)),
        ],
      ],
    );
  }

  Widget _box(int index) {
    final isActive = hasFocus && index == digits.length;
    final borderColor = hasError
        ? SharelyColors.danger
        : (isActive ? SharelyColors.primary : SharelyColors.lineStrong);
    return AnimatedContainer(
      duration: SharelyMotion.fast,
      height: 60,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: SharelyColors.surface,
        borderRadius: const BorderRadius.all(SharelyRadii.button),
        border: Border.all(color: borderColor),
        boxShadow: [
          if (isActive && !hasError)
            const BoxShadow(color: SharelyColors.primaryTint, spreadRadius: 3),
        ],
      ),
      child: Text(
        index < digits.length ? digits[index] : '',
        style: sharelyMonoStyle(size: 26, color: SharelyColors.text),
      ),
    );
  }
}
