import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:sharely/features/transfer/state/laptop_messages.dart';
import 'package:sharely/features/transfer/state/phone_messages.dart';
import 'package:sharely/features/transfer/state/received_note.dart';
import 'package:sharely_core/sharely_core.dart';

/// Phone side: what the laptop sent.
final receivedNotesProvider =
    NotifierProvider<ReceivedNotes, List<ReceivedNote>>(
      () => ReceivedNotes(laptopMessagesProvider),
    );

/// Laptop side: what paired phones sent.
final phoneNotesProvider = NotifierProvider<ReceivedNotes, List<ReceivedNote>>(
  () => ReceivedNotes(phoneMessagesProvider),
);

/// Text and links from the other device, newest first.
///
/// Kept in memory only: an OTP or a password must not outlive the app.
class ReceivedNotes extends Notifier<List<ReceivedNote>> {
  new(this._messages);

  final ProviderListenable<Stream<ProtocolMessage>> _messages;

  /// A paired device still can't fill this one's memory with notes.
  static const maxKept = 20;

  int _nextId = 0;

  @override
  List<ReceivedNote> build() {
    final subscription = ref.watch(_messages).listen(_receive);
    ref.onDispose(subscription.cancel);
    return const [];
  }

  void dismiss(int noteId) {
    state = [
      for (final note in state)
        if (note.id != noteId) note,
    ];
  }

  void _receive(ProtocolMessage message) {
    final note = switch (message) {
      TextContentMessage(:final body) => ReceivedNote(id: _nextId, text: body),
      LinkMessage(:final url) => ReceivedNote(
        id: _nextId,
        text: url.toString(),
        link: url,
      ),
      _ => null,
    };
    if (note == null) return;
    _nextId++;
    state = List.unmodifiable([note, ...state].take(maxKept));
  }
}
