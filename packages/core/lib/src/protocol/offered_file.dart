part of 'protocol_message.dart';

final _mimePattern = RegExp(r'^[A-Za-z0-9.+-]+/[A-Za-z0-9.+-]+$');

/// One file inside an [OfferMessage]. [name] is untrusted: sanitise before use.
@immutable
final class OfferedFile {
  const new({
    required this.name,
    required this.sizeBytes,
    required this.mimeType,
  });

  factory fromFields(JsonFields fields) {
    fields.requireOnlyKeys(const {'name', 'size', 'mime'});
    final mimeType = fields.string(
      'mime',
      maxLength: ProtocolLimits.maxMimeChars,
    );
    if (!_mimePattern.hasMatch(mimeType)) {
      throw const ProtocolException('"mime" is not a valid MIME type');
    }
    return OfferedFile(
      name: fields.string('name', maxLength: ProtocolLimits.maxFileNameChars),
      sizeBytes: fields.integer(
        'size',
        min: 0,
        max: ProtocolLimits.maxFileSizeBytes,
      ),
      mimeType: mimeType,
    );
  }

  final String name;
  final int sizeBytes;
  final String mimeType;

  Map<String, Object?> toJson() => {
    'name': name,
    'size': sizeBytes,
    'mime': mimeType,
  };
}
