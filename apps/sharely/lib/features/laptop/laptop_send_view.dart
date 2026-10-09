import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sharely/design/widgets/status_badge.dart';
import 'package:sharely/features/laptop/widgets/laptop_page.dart';
import 'package:sharely/features/laptop/widgets/page_heading.dart';
import 'package:sharely/features/laptop/widgets/phone_send_progress.dart';
import 'package:sharely/features/laptop/widgets/phone_send_result.dart';
import 'package:sharely/features/laptop/widgets/send_panel.dart';
import 'package:sharely/features/transfer/state/phone_send_controller.dart';
import 'package:sharely/features/transfer/state/send_state.dart';
import 'package:sharely/features/transfer/widgets/send_file_list.dart';

/// Laptop Send (D09, D10): the current send to the phone, or how to start
/// one.
class LaptopSendView extends ConsumerWidget {
  const new({required this.phoneName, required this.isConnected, super.key});

  final String phoneName;
  final bool isConnected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final send = ref.watch(phoneSendProvider);
    final controller = ref.read(phoneSendProvider.notifier);
    return LaptopPage(
      isVerticallyCentered: send is SendSucceeded || send is SendFailed,
      children: switch (send) {
        SendIdle() => [
          PageHeading(
            title: 'Send',
            subtitle: 'Drop files, or type something, to send to $phoneName.',
          ),
          SendPanel(phoneName: phoneName, isConnected: isConnected),
        ],
        SendSucceeded() || SendFailed() => [
          PhoneSendResult(
            send: send as SendWithFiles,
            phoneName: phoneName,
            onDone: controller.dismiss,
          ),
        ],
        SendWithFiles() => [
          PageHeading(
            overline: 'Sending to',
            title: phoneName,
            trailing: StatusBadge(
              label: isConnected ? 'Connected' : 'Disconnected',
              tone: isConnected ? StatusTone.connected : StatusTone.offline,
            ),
          ),
          PhoneSendProgress(
            send: send,
            phoneName: phoneName,
            onCancel: controller.cancel,
          ),
          SendFileList(
            files: send.files,
            bytesSent: send is SendInProgress ? send.bytesSent : 0,
          ),
        ],
      },
    );
  }
}
