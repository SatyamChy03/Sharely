part of 'protocol_message.dart';

/// "Are you still there?" and its answer.
///
/// A socket can look open long after the other side has gone, for example
/// after a phone was frozen. Asking is the only way to know right now.
final class HeartbeatMessage extends ProtocolMessage {
  const new _(this.type, this.id);

  const new ping(String id) : this._(MessageType.ping, id);

  const new pong(String id) : this._(MessageType.pong, id);

  factory fromFields(MessageType type, JsonFields fields) {
    fields.requireOnlyKeys(const {'type', 'id'});
    return HeartbeatMessage._(type, fields.id('id'));
  }

  @override
  final MessageType type;

  /// Ties an answer to its question, so an old answer proves nothing.
  final String id;

  @override
  Map<String, Object?> toJson() => {'type': type.name, 'id': id};
}
