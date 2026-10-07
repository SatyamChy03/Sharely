import 'dart:typed_data';

/// Length of the XXH64 digest an upload carries after the file's bytes.
///
/// Sending it last lets the sender hash while it streams, instead of
/// reading the whole file once beforehand just to fill in the offer.
const uploadChecksumBytes = 8;

/// The digest as the big-endian bytes that end an upload body.
Uint8List encodeUploadChecksum(int digest) =>
    Uint8List(uploadChecksumBytes)..buffer.asByteData().setUint64(0, digest);

/// Reads a digest written by [encodeUploadChecksum].
int decodeUploadChecksum(Uint8List bytes) =>
    ByteData.sublistView(bytes).getUint64(0);
