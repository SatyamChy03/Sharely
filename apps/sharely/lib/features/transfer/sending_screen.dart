import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sharely/design/theme.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/design/widgets/sharely_button.dart';
import 'package:sharely/features/pairing/state/paired_devices.dart';
import 'package:sharely/features/transfer/state/send_controller.dart';
import 'package:sharely/features/transfer/state/send_state.dart';
import 'package:sharely/features/transfer/transfer_formatting.dart';
import 'package:sharely/features/transfer/widgets/send_file_list.dart';
import 'package:sharely/features/transfer/widgets/send_progress_ring.dart';
import 'package:sharely/features/transfer/widgets/send_stat_tile.dart';

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
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                child: switch (send) {
                  SendWithFiles() => _SendBody(
                    send: send,
                    laptopName: laptopName,
                  ),
                  SendIdle() => const SizedBox.shrink(),
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SendBody extends ConsumerWidget {
  const new({required this.send, required this.laptopName});

  final SendWithFiles send;
  final String laptopName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bytesSent = switch (send) {
      SendInProgress(:final bytesSent) => bytesSent,
      SendSucceeded(:final totalBytes) => totalBytes,
      _ => 0,
    };
    final note = _note();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 22,
      children: [
        _Header(laptopName: laptopName),
        Expanded(
          child: ListView(
            children: [
              Center(child: _ring()),
              const SizedBox(height: 22),
              _stats(),
              if (note != null) ...[
                const SizedBox(height: SharelySpacing.lg),
                _NoteCard(note),
              ],
              const SizedBox(height: SharelySpacing.lg),
              SendFileList(files: send.files, bytesSent: bytesSent),
            ],
          ),
        ),
        ..._actions(context, ref),
      ],
    );
  }

  Widget _ring() => switch (send) {
    SendInProgress(:final fraction, :final bytesPerSecond) => SendProgressRing(
      fraction: fraction,
      headline: '${(fraction * 100).floor()}%',
      caption: bytesPerSecond > 0 ? formatSpeed(bytesPerSecond) : 'starting',
    ),
    SendSucceeded() => const SendProgressRing(
      fraction: 1,
      headline: '100%',
      caption: 'sent',
    ),
    SendFailed() => const SendProgressRing(
      fraction: 0,
      headline: '—',
      caption: 'stopped',
    ),
    SendAwaitingAcceptance() => const SendProgressRing(
      fraction: 0,
      headline: '0%',
      caption: 'waiting',
    ),
    SendPreparing() => const SendProgressRing(
      fraction: 0,
      headline: '0%',
      caption: 'getting ready',
    ),
  };

  Widget _stats() {
    final filesDone = switch (send) {
      SendInProgress() && final progress => progress.filesDone,
      SendSucceeded() => send.fileCount,
      _ => 0,
    };
    final timeLeft = switch (send) {
      SendInProgress(:final timeLeft?) => '~${formatDurationShort(timeLeft)}',
      SendSucceeded() => 'done',
      _ => '—',
    };
    return Row(
      spacing: 10,
      children: [
        Expanded(
          child: SendStatTile(
            label: 'Files',
            value: '$filesDone / ${send.fileCount}',
          ),
        ),
        Expanded(
          child: SendStatTile(label: 'Time left', value: timeLeft),
        ),
      ],
    );
  }

  String? _note() => switch (send) {
    SendAwaitingAcceptance() => 'Accept on $laptopName to start.',
    SendSucceeded() => 'Saved in Downloads/Sharely on $laptopName.',
    SendFailed(:final reason) => describeSendFailure(reason),
    _ => null,
  };

  List<Widget> _actions(BuildContext context, WidgetRef ref) {
    if (send is SendSucceeded || send is SendFailed) {
      return [
        SharelyButton(
          label: send is SendSucceeded ? 'Done' : 'Back to home',
          onPressed: context.pop,
        ),
      ];
    }
    return [
      Text(
        'Keeps going if you leave this screen',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: SharelyColors.onInkMuted),
      ),
      SharelyButton(
        label: 'Cancel',
        variant: SharelyButtonVariant.outline,
        onPressed: ref.read(sendProvider.notifier).cancel,
      ),
    ];
  }
}

class _Header extends StatelessWidget {
  const new({required this.laptopName});

  final String laptopName;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      spacing: SharelySpacing.md,
      children: [
        IconButton.filled(
          tooltip: 'Minimise',
          onPressed: context.pop,
          style: IconButton.styleFrom(
            backgroundColor: SharelyColors.inkRaised,
            foregroundColor: SharelyColors.surface,
            fixedSize: const Size.square(44),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(14)),
            ),
          ),
          icon: const Icon(LucideIcons.chevronDown, size: 20),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 1,
            children: [
              Text(
                'Sending to',
                style: textTheme.bodySmall?.copyWith(
                  color: SharelyColors.onInkMuted,
                ),
              ),
              Text(
                laptopName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleMedium?.copyWith(fontSize: 17),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NoteCard extends StatelessWidget {
  const new(this.note);

  final String note;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        color: SharelyColors.inkRaised,
        borderRadius: BorderRadius.all(Radius.circular(18)),
      ),
      child: Text(
        note,
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(color: SharelyColors.onInkSoft),
      ),
    );
  }
}
