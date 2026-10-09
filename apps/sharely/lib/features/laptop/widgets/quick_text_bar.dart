import 'package:flutter/material.dart';
import 'package:sharely/design/tokens.dart';

/// "Paste a link, a note or an OTP…" with an accent Send.
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
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 8, 8, 8),
      decoration: const BoxDecoration(
        color: SharelyColors.surface,
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
      child: Row(
        spacing: 10,
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              enabled: onSend != null,
              onSubmitted: (_) => _send(),
              decoration: const InputDecoration(
                hintText: 'Paste a link, a note or an OTP…',
                border: InputBorder.none,
                filled: false,
                isDense: true,
              ),
            ),
          ),
          FilledButton(
            onPressed: onSend == null ? null : _send,
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 44),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              backgroundColor: SharelyColors.accent,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(14)),
              ),
            ),
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }
}
