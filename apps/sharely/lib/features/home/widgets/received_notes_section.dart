import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/features/transfer/state/received_notes.dart';
import 'package:sharely/features/transfer/widgets/received_note_card.dart';

/// Text and links the laptop just sent; empty space when there are none.
class ReceivedNotesSection extends ConsumerWidget {
  const new({super.key});

  // Older notes come into view as newer ones are dismissed.
  static const _shownAtOnce = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(receivedNotesProvider);
    if (notes.isEmpty) return const SizedBox.shrink();
    final controller = ref.read(receivedNotesProvider.notifier);
    return Padding(
      padding: const EdgeInsets.only(bottom: SharelySpacing.page),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: SharelySpacing.sm,
        children: [
          for (final note in notes.take(_shownAtOnce))
            ReceivedNoteCard(
              key: ValueKey(note.id),
              note: note,
              sourceName: 'laptop',
              onDismiss: () => controller.dismiss(note.id),
            ),
        ],
      ),
    );
  }
}
