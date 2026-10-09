import 'package:flutter/foundation.dart';

/// Text or a link the other device sent, shown until dismissed.
@immutable
final class ReceivedNote {
  const new({required this.id, required this.text, this.link});

  /// Unique within this run of the app; notes are never stored.
  final int id;
  final String text;

  /// Set when the laptop sent a web link; always http or https.
  final Uri? link;
}
