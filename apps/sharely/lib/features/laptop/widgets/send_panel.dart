import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/features/laptop/laptop_send_actions.dart';
import 'package:sharely/features/laptop/widgets/drop_zone_card.dart';
import 'package:sharely/features/laptop/widgets/quick_text_bar.dart';
import 'package:sharely/features/transfer/state/phone_send_controller.dart';
import 'package:sharely/features/transfer/state/send_state.dart';

/// Everything that starts a send to the phone: the drop zone and quick text.
class SendPanel extends ConsumerWidget {
  const new({required this.phoneName, required this.isConnected, super.key});

  final String phoneName;
  final bool isConnected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(phoneSendProvider.notifier);
    final canSend = isConnected && ref.watch(phoneSendProvider) is SendIdle;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: SharelySpacing.lg,
      children: [
        DropZoneCard(
          phoneName: phoneName,
          onChooseFiles: canSend ? controller.pickAndSendFiles : null,
          onChooseFolder: canSend ? controller.pickAndSendFolder : null,
          onDropPaths: canSend ? controller.sendPaths : null,
        ),
        QuickTextBar(
          onSend: isConnected
              ? (text) => sendTextFromLaptop(context, ref, text, phoneName)
              : null,
        ),
        if (!isConnected)
          Text(
            'Open Sharely on $phoneName, on the same Wi-Fi, to send to it.',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: SharelyColors.textSecondary),
          ),
      ],
    );
  }
}
