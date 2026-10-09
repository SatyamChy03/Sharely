import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sharely/design/input_decoration.dart';
import 'package:sharely/design/widgets/sharely_button.dart';
import 'package:sharely/design/widgets/sheet_grabber.dart';

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
        10,
        20,
        28 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 18,
        children: [
          const Center(child: SheetGrabber()),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Send to ${widget.laptopName}',
                  style: textTheme.headlineSmall,
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
            style: textTheme.bodyMedium,
            decoration: sharelyInputDecoration(
              hintText: 'A link, a note or an OTP…',
            ),
          ),
          SharelyButton(
            label: 'Send',
            leadingIcon: LucideIcons.arrowUp,
            onPressed: _send,
          ),
        ],
      ),
    );
  }
}
