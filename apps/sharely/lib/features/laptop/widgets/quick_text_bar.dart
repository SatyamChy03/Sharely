import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sharely/design/input_decoration.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/design/widgets/sharely_button.dart';

/// "Paste a link, a note or an OTP…" with a Send button.
class QuickTextBar extends StatefulWidget {
  const new({required this.onSend, super.key});

  /// Returns whether the text went out, which clears the field. Null while
  /// the phone isn't connected.
  final bool Function(String text)? onSend;

  @override
  State<QuickTextBar> createState() => _QuickTextBarState();
}

class _QuickTextBarState extends State<QuickTextBar> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final wasSent = widget.onSend?.call(_controller.text) ?? false;
    if (wasSent) _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final onSend = widget.onSend;
    return Row(
      spacing: 10,
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            enabled: onSend != null,
            onSubmitted: (_) => _send(),
            style: Theme.of(context).textTheme.bodyMedium,
            decoration: sharelyInputDecoration(
              hintText: 'Paste a link, a note or an OTP…',
              prefixIcon: const Icon(LucideIcons.link, size: 16),
            ).copyWith(fillColor: SharelyColors.surface),
          ),
        ),
        SharelyButton(
          label: 'Send',
          leadingIcon: LucideIcons.arrowUp,
          variant: SharelyButtonVariant.secondary,
          height: SharelySizes.buttonMedium,
          isExpanded: false,
          onPressed: onSend == null ? null : _send,
        ),
      ],
    );
  }
}
