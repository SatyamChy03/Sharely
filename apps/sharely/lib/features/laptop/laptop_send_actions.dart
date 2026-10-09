import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sharely/features/transfer/state/phone_send_controller.dart';
import 'package:sharely/features/transfer/state/quick_text_result.dart';

/// Sends [text] to the phone and says what happened in a snack bar.
bool sendTextFromLaptop(
  BuildContext context,
  WidgetRef ref,
  String text,
  String phoneName,
) {
  final result = ref.read(phoneSendProvider.notifier).sendText(text);
  final notice = switch (result) {
    QuickTextResult.sent => 'Sent to $phoneName.',
    QuickTextResult.empty => 'Type or paste something to send first.',
    QuickTextResult.tooLong =>
      'That is too long to send as text. Save it as a file and send that.',
    QuickTextResult.notConnected =>
      "$phoneName isn't connected. Open Sharely on it and try again.",
  };
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(notice)));
  return result == QuickTextResult.sent;
}
