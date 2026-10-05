import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sharely/design/theme.dart';
import 'package:sharely/design/widgets/sharely_button.dart';
import 'package:sharely/features/pairing/state/paired_devices.dart';
import 'package:sharely/features/transfer/state/send_controller.dart';
import 'package:sharely/features/transfer/state/send_state.dart';
import 'package:sharely/features/transfer/widgets/send_progress_panel.dart';

/// Phone, dark: one send from waiting for the laptop through to done.
class SendingScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final send = ref.watch(sendProvider);
    final devices = ref.watch(pairedDevicesProvider).value ?? const [];
    final laptopName = devices.lastOrNull?.deviceName ?? 'your laptop';
    final isFinished = send is SendSucceeded || send is SendFailed;
    return Theme(
      data: SharelyTheme.dark(),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        // Leaving mid-send would hide a transfer that is still running.
        child: PopScope(
          canPop: isFinished || send is SendIdle,
          // Leaving with system back clears the result, so Send works again.
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) ref.read(sendProvider.notifier).dismiss();
          },
          child: Scaffold(
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Center(
                        child: SendProgressPanel(
                          send: send,
                          laptopName: laptopName,
                        ),
                      ),
                    ),
                    _buildAction(context, ref, send, isFinished: isFinished),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAction(
    BuildContext context,
    WidgetRef ref,
    SendState send, {
    required bool isFinished,
  }) {
    final controller = ref.read(sendProvider.notifier);
    if (!isFinished) {
      return SharelyButton(
        label: 'Cancel',
        variant: SharelyButtonVariant.outline,
        onPressed: send is SendIdle ? null : controller.cancel,
      );
    }
    return SharelyButton(
      label: send is SendSucceeded ? 'Done' : 'Back to home',
      trailingIcon: send is SendSucceeded ? LucideIcons.check : null,
      onPressed: context.pop,
    );
  }
}
