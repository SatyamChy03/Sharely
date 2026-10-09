import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/design/widgets/icon_square_button.dart';
import 'package:sharely/design/widgets/sharely_button.dart';
import 'package:sharely/design/widgets/surface_card.dart';
import 'package:sharely/features/transfer/state/send_controller.dart';
import 'package:sharely/features/transfer/state/send_state.dart';
import 'package:sharely/features/transfer/transfer_formatting.dart';
import 'package:sharely/features/transfer/widgets/send_file_list.dart';
import 'package:sharely/features/transfer/widgets/send_progress_ring.dart';
import 'package:sharely/features/transfer/widgets/send_stat_tile.dart';

/// A send that is still running (M09): ring, speed, the queue and Cancel.
class SendProgressView extends ConsumerWidget {
  const new({required this.send, required this.laptopName, super.key});

  final SendWithFiles send;
  final String laptopName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = switch (send) {
      SendInProgress() && final running => running,
      _ => null,
    };
    final bytesSent = progress?.bytesSent ?? 0;
    final note = _note(progress);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: SharelySpacing.lg,
      children: [
        _Header(laptopName: laptopName),
        Expanded(
          child: ListView(
            children: [
              Center(
                child: SendProgressRing(
                  fraction: progress?.fraction ?? 0,
                  isStalled: progress?.isReconnecting ?? false,
                  caption:
                      '${formatByteCount(bytesSent)} / '
                      '${formatByteCount(send.totalBytes)}',
                ),
              ),
              const SizedBox(height: SharelySpacing.lg),
              _stats(progress),
              if (note != null) ...[
                const SizedBox(height: SharelySpacing.md),
                _NoteCard(note),
              ],
              const SizedBox(height: SharelySpacing.md),
              SendFileList(files: send.files, bytesSent: bytesSent),
            ],
          ),
        ),
        Text(
          'Keeps going if you leave this screen',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: SharelyColors.textSecondary),
        ),
        SharelyButton(
          label: 'Cancel',
          variant: SharelyButtonVariant.danger,
          onPressed: ref.read(sendProvider.notifier).cancel,
        ),
      ],
    );
  }

  Widget _stats(SendInProgress? progress) {
    final speed = progress == null || progress.isReconnecting
        ? '—'
        : (progress.bytesPerSecond > 0
              ? formatSpeed(progress.bytesPerSecond)
              : 'Starting');
    final timeLeft = switch (progress?.timeLeft) {
      final left? when !(progress?.isReconnecting ?? false) =>
        '~${formatDurationShort(left)}',
      _ => '—',
    };
    return Row(
      spacing: 10,
      children: [
        Expanded(
          child: SendStatTile(label: 'Speed', value: speed),
        ),
        Expanded(
          child: SendStatTile(label: 'Time left', value: timeLeft),
        ),
      ],
    );
  }

  String? _note(SendInProgress? progress) {
    if (progress?.isReconnecting ?? false) {
      return 'Lost the connection to $laptopName. The send continues by '
          'itself when the Wi-Fi is back.';
    }
    return switch (send) {
      SendAwaitingAcceptance() => 'Accept on $laptopName to start.',
      SendPreparing() => 'Getting your files ready…',
      _ => null,
    };
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
        IconSquareButton(
          icon: LucideIcons.chevronDown,
          tooltip: 'Minimise',
          onPressed: context.pop,
        ),
        Text('Sending', style: textTheme.headlineSmall),
        const Spacer(),
        Flexible(
          flex: 4,
          child: SurfaceCard(
            radius: SharelyRadii.row,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: SharelySpacing.sm,
              children: [
                const Icon(
                  LucideIcons.laptop,
                  size: 15,
                  color: SharelyColors.primary,
                ),
                Flexible(
                  child: Text(
                    'To $laptopName',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
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
    return SurfaceCard(
      radius: SharelyRadii.tile,
      color: SharelyColors.elevated,
      borderColor: SharelyColors.lineStrong,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Semantics(
        liveRegion: true,
        child: Text(note, style: Theme.of(context).textTheme.labelMedium),
      ),
    );
  }
}
