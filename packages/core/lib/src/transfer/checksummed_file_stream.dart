import 'dart:io';
import 'dart:typed_data';

import 'package:sharely_core/src/transfer/outgoing_file.dart';
import 'package:sharely_core/src/transfer/upload_checksum.dart';
import 'package:sharely_core/src/transfer/xxh64_accumulator.dart';

/// The bytes of [file] from [offset] on, then the checksum of the whole file.
///
/// A resumed send still reads from the start: the bytes before [offset] are
/// hashed but not yielded, so the checksum always covers the entire file and
/// a source that changed since the first attempt is caught.
///
/// Stops early, without the checksum, once [shouldStop] returns true. Throws
/// [FileSystemException] when the file no longer matches its declared size.
Stream<List<int>> readFileWithChecksum(
  OutgoingFile file, {
  required bool Function() shouldStop,
  required void Function(int byteCount) onBytesYielded,
  int offset = 0,
}) async* {
  final hasher = Xxh64Accumulator();
  var bytesRead = 0;
  await for (final chunk in file.openRead()) {
    if (shouldStop()) return;
    final chunkStart = bytesRead;
    bytesRead += chunk.length;
    if (bytesRead > file.sizeBytes) {
      throw FileSystemException('Grew while sending', file.name);
    }
    hasher.add(chunk);
    if (bytesRead <= offset) continue;
    final unsent = chunkStart >= offset
        ? chunk
        : Uint8List.sublistView(_asBytes(chunk), offset - chunkStart);
    onBytesYielded(unsent.length);
    yield unsent;
  }
  if (bytesRead != file.sizeBytes) {
    throw FileSystemException('Shrank while sending', file.name);
  }
  if (shouldStop()) return;
  yield encodeUploadChecksum(hasher.finish());
}

Uint8List _asBytes(List<int> chunk) =>
    chunk is Uint8List ? chunk : Uint8List.fromList(chunk);
