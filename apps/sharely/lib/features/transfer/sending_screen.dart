import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sharely/features/pairing/state/paired_devices.dart';
import 'package:sharely/features/transfer/state/send_controller.dart';
import 'package:sharely/features/transfer/state/send_state.dart';
import 'package:sharely/features/transfer/widgets/send_progress_view.dart';
import 'package:sharely/features/transfer/widgets/send_result_view.dart';

/// Phone: one send from waiting for the laptop through to done (M09, M10).
class SendingScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final send = ref.watch(sendProvider);
    final devices = ref.watch(pairedDevicesProvider).value ?? const [];
    final laptopName = devices.lastOrNull?.deviceName ?? 'your laptop';
    final isFinished = send is SendSucceeded || send is SendFailed;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: PopScope(
        // A running send keeps going in the background; a finished one
        // is cleared on the way out so Send works again.
        onPopInvokedWithResult: (didPop, _) {
          if (didPop && isFinished) {
            ref.read(sendProvider.notifier).dismiss();
          }
        },
        child: Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              child: switch (send) {
                SendWithFiles() when isFinished => SendResultView(
                  send: send,
                  laptopName: laptopName,
                ),
                SendWithFiles() => SendProgressView(
                  send: send,
                  laptopName: laptopName,
                ),
                SendIdle() => const SizedBox.shrink(),
              },
            ),
          ),
        ),
      ),
    );
  }
}
