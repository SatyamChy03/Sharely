import 'dart:convert';

import 'package:sharely_core/src/protocol/json_fields.dart';
import 'package:sharely_core/src/protocol/protocol_exception.dart';
import 'package:sharely_core/src/protocol/protocol_limits.dart';
import 'package:sharely_core/src/protocol/protocol_message.dart';

/// Converts control-channel messages to and from their JSON wire form.
abstract final class MessageCodec {
  static String encode(ProtocolMessage message) {
    return jsonEncode(message.toJson());
  }

  /// Parses an untrusted frame. Throws [ProtocolException] on any violation.
  static ProtocolMessage decode(String frame) {
    // Size check runs before parsing so oversized frames cost nothing.
    if (frame.length > ProtocolLimits.maxMessageChars) {
      throw const ProtocolException('Message is too large');
    }
    final fields = JsonFields(decodeJsonObject(frame));
    final type = MessageType.fromWireName(fields.string('type', maxLength: 32));
    return switch (type) {
      MessageType.hello => HelloMessage.fromFields(fields),
      MessageType.offer => OfferMessage.fromFields(fields),
      MessageType.accept ||
      MessageType.reject ||
      MessageType.cancel => TransferDecisionMessage.fromFields(type, fields),
      MessageType.progress => ProgressMessage.fromFields(fields),
      MessageType.text ||
      MessageType.clipboard => TextContentMessage.fromFields(type, fields),
      MessageType.link => LinkMessage.fromFields(fields),
    };
  }
}
