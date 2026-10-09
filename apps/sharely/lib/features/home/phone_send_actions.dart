import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sharely/app/routes.dart';
import 'package:sharely/features/home/widgets/quick_text_sheet.dart';
import 'package:sharely/features/transfer/state/quick_text_result.dart';
import 'package:sharely/features/transfer/state/send_controller.dart';

/// Lets the user pick files, then opens the progress screen once they go.
Future<void> pickAndSendFromPhone(
  BuildContext context,
  WidgetRef ref, {
  required bool photosOnly,
}) async {
  final notifier = ref.read(sendProvider.notifier);
  final started = await notifier.pickAndSend(photosOnly: photosOnly);
  if (started && context.mounted) await context.push(AppRoutes.sending);
}

/// Sends [text] to the laptop and says what happened in a snack bar.
bool sendTextFromPhone(
  BuildContext context,
  WidgetRef ref,
  String text, {
  String emptyNotice = 'Type or paste something to send first.',
}) {
  final result = ref.read(sendProvider.notifier).sendText(text);
  final notice = switch (result) {
    QuickTextResult.sent => 'Sent to your laptop.',
    QuickTextResult.empty => emptyNotice,
    QuickTextResult.tooLong =>
      'That is too long to send as text. Save it as a file and send that.',
    QuickTextResult.notConnected =>
      "Your laptop isn't connected. Open Sharely on it and try again.",
  };
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(notice)));
  return result == QuickTextResult.sent;
}

/// Sends what is on the clipboard; the user asked for it by tapping the tile.
Future<void> sendClipboardFromPhone(BuildContext context, WidgetRef ref) async {
  final clipboard = await Clipboard.getData(Clipboard.kTextPlain);
  if (!context.mounted) return;
  sendTextFromPhone(
    context,
    ref,
    clipboard?.text ?? '',
    emptyNotice: 'There is no text on the clipboard. Copy some first.',
  );
}

Future<void> openQuickTextSheet(
  BuildContext context,
  WidgetRef ref,
  String laptopName,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => QuickTextSheet(
      laptopName: laptopName,
      onSend: (text) => sendTextFromPhone(context, ref, text),
    ),
  );
}
