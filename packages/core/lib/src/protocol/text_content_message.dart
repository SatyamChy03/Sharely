part of 'protocol_message.dart';

/// Plain text or clipboard content. Line breaks and tabs are allowed.
final class TextContentMessage extends ProtocolMessage {
  const new _(this.type, this.body);

  const new text(String body) : this._(MessageType.text, body);

  const new clipboard(String body) : this._(MessageType.clipboard, body);

  factory fromFields(MessageType type, JsonFields fields) {
    fields.requireOnlyKeys(const {'type', 'body'});
    final body = fields.string(
      'body',
      maxLength: ProtocolLimits.maxTextChars,
      allowControlCharacters: true,
    );
    if (body.contains('\u0000')) {
      throw const ProtocolException('"body" contains a NUL character');
    }
    return TextContentMessage._(type, body);
  }

  @override
  final MessageType type;
  final String body;

  @override
  Map<String, Object?> toJson() => {'type': type.name, 'body': body};
}
