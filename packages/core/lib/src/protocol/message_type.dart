part of 'protocol_message.dart';

/// Every message type on the control channel, by its wire name.
enum MessageType {
  hello,
  offer,
  accept,
  reject,
  progress,
  cancel,
  text,
  link,
  clipboard;

  static MessageType fromWireName(String wireName) {
    for (final type in values) {
      if (type.name == wireName) return type;
    }
    throw const ProtocolException('Unknown message type');
  }
}
