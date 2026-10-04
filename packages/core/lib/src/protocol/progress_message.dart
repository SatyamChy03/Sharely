part of 'protocol_message.dart';

/// Total bytes moved so far for a transfer.
final class ProgressMessage extends ProtocolMessage {
  const new({required this.transferId, required this.bytes});

  factory fromFields(JsonFields fields) {
    fields.requireOnlyKeys(const {'type', 'transferId', 'bytes'});
    return ProgressMessage(
      transferId: fields.id('transferId'),
      bytes: fields.integer(
        'bytes',
        min: 0,
        max: ProtocolLimits.maxTransferBytes,
      ),
    );
  }

  final String transferId;
  final int bytes;

  @override
  MessageType get type => MessageType.progress;

  @override
  Map<String, Object?> toJson() => {
    'type': type.name,
    'transferId': transferId,
    'bytes': bytes,
  };
}
