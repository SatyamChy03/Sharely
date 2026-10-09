import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/features/transfer/state/incoming_transfers_controller.dart';
import 'package:sharely/features/transfer/state/received_note.dart';
import 'package:sharely/features/transfer/state/received_notes.dart';
import 'package:sharely/features/transfer/widgets/incoming_transfer_card.dart';
import 'package:sharely/features/transfer/widgets/received_note_card.dart';

/// Stacks incoming transfers and notes in the bottom-right corner, never
/// blocking the window.
class IncomingTransfersOverlay extends ConsumerWidget {
  const new({super.key});

  // Older notes come into view as newer ones are dismissed.
  static const _notesShownAtOnce = 2;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final views = ref.watch(incomingTransfersProvider);
    final notes = ref.watch(phoneNotesProvider);
    final notesController = ref.read(phoneNotesProvider.notifier);
    return Positioned(
      right: SharelySpacing.xl,
      bottom: SharelySpacing.xl,
      // Cards fill up to their max width but never wider than the window.
      left: SharelySpacing.xl,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final note in notes.take(_notesShownAtOnce))
            Padding(
              key: ValueKey('note-${note.id}'),
              padding: const EdgeInsets.only(top: SharelySpacing.md),
              child: _NoteNotification(
                note: note,
                onDismiss: () => notesController.dismiss(note.id),
              ),
            ),
          for (final view in views)
            Padding(
              key: ValueKey(view.transferId),
              padding: const EdgeInsets.only(top: SharelySpacing.md),
              child: IncomingTransferCard(view: view)
                  .animate()
                  .fadeIn(duration: SharelyMotion.medium)
                  .slideY(begin: 0.2, curve: SharelyMotion.emphasized),
            ),
        ],
      ),
    );
  }
}

/// A note from the phone, lifted off the page like the transfer cards.
class _NoteNotification extends StatelessWidget {
  const new({required this.note, required this.onDismiss});

  final ReceivedNote note;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: IncomingTransferCard.maxWidth,
        ),
        child: Material(
          color: SharelyColors.surface,
          elevation: 12,
          shadowColor: SharelyColors.ink.withValues(alpha: 0.4),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(SharelyRadii.tile),
            side: BorderSide(color: SharelyColors.mist),
          ),
          child: ReceivedNoteCard(
            note: note,
            sourceName: 'phone',
            onDismiss: onDismiss,
          ),
        ),
      ).animate().fadeIn(duration: SharelyMotion.medium),
    );
  }
}
