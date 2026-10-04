part of 'protocol_message.dart';

/// Accept, reject and cancel carry only the transfer they refer to.
final class TransferDecisionMessage extends ProtocolMessage {
  const new _(this.type, this.transferId);

  const new accept(String transferId) : this._(MessageType.accept, transferId);

  const new reject(String transferId) : this._(MessageType.reject, transferId);

  const new cancel(String transferId) : this._(MessageType.cancel, transferId);

  factory fromFields(MessageType type, JsonFields fields) {
    fields.requireOnlyKeys(const {'type', 'transferId'});
    return TransferDecisionMessage._(type, fields.id('transferId'));
  }

  @override
  final MessageType type;
  final String transferId;

  @override
  Map<String, Object?> toJson() => {
    'type': type.name,
    'transferId': transferId,
  };
}
