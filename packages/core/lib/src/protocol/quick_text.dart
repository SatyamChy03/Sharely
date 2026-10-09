import 'package:sharely_core/src/protocol/message_codec.dart';
import 'package:sharely_core/src/protocol/protocol_exception.dart';
import 'package:sharely_core/src/protocol/protocol_limits.dart';
import 'package:sharely_core/src/protocol/protocol_message.dart';

final _whitespace = RegExp(r'\s');

/// Turns what the user typed or pasted into the message to send: a link
/// when it is one safe web address, plain text otherwise.
///
/// Throws [ProtocolException] when it is empty or too long to send.
ProtocolMessage composeQuickText(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) throw const ProtocolException('Text is empty');
  final message = _asLink(trimmed) ?? TextContentMessage.text(raw);
  // Decoding our own frame applies every limit the receiver will, so a
  // message that would get the connection closed is never sent.
  MessageCodec.decode(MessageCodec.encode(message));
  return message;
}

LinkMessage? _asLink(String text) {
  if (text.length > ProtocolLimits.maxUrlChars || _whitespace.hasMatch(text)) {
    return null;
  }
  try {
    return LinkMessage.parse(text);
  } on ProtocolException {
    return null;
  }
}
