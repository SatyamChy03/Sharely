import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/design/widgets/sharely_button.dart';

/// Phone sheet for typing or pasting a link, a note or an OTP to send.
class QuickTextSheet extends StatefulWidget {
  const new({required this.laptopName, required this.onSend, super.key});

  final String laptopName;

  /// Returns whether the text went out, which closes the sheet.
  final bool Function(String text) onSend;

  @override
  State<QuickTextSheet> createState() => _QuickTextSheetState();
}

class _QuickTextSheetState extends State<QuickTextSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final clipboard = await Clipboard.getData(Clipboard.kTextPlain);
    final text = clipboard?.text;
    if (text != null && mounted) _controller.text = text;
  }

  void _send() {
    if (widget.onSend(_controller.text)) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      // Keeps the field and Send above the keyboard.
      padding: EdgeInsets.fromLTRB(
        20,
        4,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: SharelySpacing.lg,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Send to ${widget.laptopName}',
                  style: textTheme.headlineMedium?.copyWith(fontSize: 22),
                ),
              ),
              TextButton.icon(
                onPressed: () => unawaited(_paste()),
                icon: const Icon(LucideIcons.clipboardPaste, size: 16),
                label: const Text('Paste'),
              ),
            ],
          ),
          TextField(
            controller: _controller,
            autofocus: true,
            minLines: 3,
            maxLines: 6,
            keyboardType: TextInputType.multiline,
            decoration: const InputDecoration(
              hintText: 'A link, a note or an OTP…',
              filled: true,
              fillColor: SharelyColors.paper,
              border: OutlineInputBorder(
                borderSide: BorderSide.none,
                borderRadius: BorderRadius.all(SharelyRadii.button),
              ),
            ),
          ),
          SharelyButton(
            label: 'Send',
            variant: SharelyButtonVariant.ink,
            trailingIcon: LucideIcons.arrowUp,
            onPressed: _send,
          ),
        ],
      ),
    );
  }
}
