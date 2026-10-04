part of 'protocol_message.dart';

/// Sender proposes files; the receiver must accept or reject.
final class OfferMessage extends ProtocolMessage {
  const new({required this.transferId, required this.files});

  factory fromFields(JsonFields fields) {
    fields.requireOnlyKeys(const {'type', 'transferId', 'files'});
    final files = fields.objectList(
      'files',
      minLength: 1,
      maxLength: ProtocolLimits.maxFilesPerOffer,
    );
    return OfferMessage(
      transferId: fields.id('transferId'),
      files: List.unmodifiable(files.map(OfferedFile.fromFields)),
    );
  }

  final String transferId;
  final List<OfferedFile> files;

  int get totalBytes => files.fold(0, (sum, file) => sum + file.sizeBytes);

  @override
  MessageType get type => MessageType.offer;

  @override
  Map<String, Object?> toJson() => {
    'type': type.name,
    'transferId': transferId,
    'files': [for (final file in files) file.toJson()],
  };
}
