part of 'protocol_message.dart';

final _mimePattern = RegExp(r'^[A-Za-z0-9.+-]+/[A-Za-z0-9.+-]+$');
final _sha256Pattern = RegExp(r'^[0-9a-f]{64}$');

/// One file inside an [OfferMessage]. [name] is untrusted: sanitise before use.
@immutable
final class OfferedFile {
  const new({
    required this.name,
    required this.sizeBytes,
    required this.mimeType,
    required this.sha256,
  });

  factory fromFields(JsonFields fields) {
    fields.requireOnlyKeys(const {'name', 'size', 'mime', 'sha256'});
    final sha256 = fields.string('sha256', minLength: 64, maxLength: 64);
    if (!_sha256Pattern.hasMatch(sha256)) {
      throw const ProtocolException('"sha256" must be lowercase hex');
    }
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
      sha256: sha256,
    );
  }

  final String name;
  final int sizeBytes;
  final String mimeType;

  /// Lowercase hex SHA-256 of the whole file; the receiver keeps only a match.
  final String sha256;

  Map<String, Object?> toJson() => {
    'name': name,
    'size': sizeBytes,
    'mime': mimeType,
    'sha256': sha256,
  };
}
