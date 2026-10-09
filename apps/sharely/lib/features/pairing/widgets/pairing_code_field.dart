import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/design/typography.dart';

/// Six mono digit boxes over one hidden field, as the laptop shows the code.
class PairingCodeField extends StatefulWidget {
  const new({required this.onChanged, super.key, this.isEnabled = true});

  final ValueChanged<String> onChanged;
  final bool isEnabled;

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
  const new({required this.digits, required this.hasFocus});

  final String digits;
  final bool hasFocus;

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: SharelySpacing.sm,
      children: [
        for (var index = 0; index < PairingCodeField.length; index++)
          Expanded(
            child: AnimatedContainer(
              duration: SharelyMotion.fast,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: SharelyColors.surface,
                borderRadius: const BorderRadius.all(Radius.circular(16)),
                border: Border.all(
                  color: hasFocus && index == digits.length
                      ? SharelyColors.accent
                      : SharelyColors.mist,
                  width: 1.5,
                ),
              ),
              child: Text(
                index < digits.length ? digits[index] : '',
                style: sharelyMonoStyle(size: 28, color: SharelyColors.ink),
              ),
            ),
          ),
      ],
    );
  }
}
