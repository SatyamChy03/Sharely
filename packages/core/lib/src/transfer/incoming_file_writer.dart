import 'dart:io';
import 'dart:typed_data';

import 'package:sharely_core/src/protocol/protocol_message.dart';
import 'package:sharely_core/src/security/safe_file_creator.dart';
import 'package:sharely_core/src/transfer/transfer_exception.dart';
import 'package:sharely_core/src/transfer/upload_checksum.dart';
import 'package:sharely_core/src/transfer/xxh64_accumulator.dart';

// Network chunks are small; one disk write per chunk wastes most of the time.
const int _writeBatchBytes = 4 << 20;

/// Streams one upload to a new file in [saveDirectory], chunk by chunk.
///
/// The body is the file's bytes followed by its checksum. The file is kept
/// only if its size and checksum match; on any failure the partial file is
/// deleted and the error is rethrown.
Future<File> writeIncomingFile({
  required Stream<List<int>> body,
  required Directory saveDirectory,
  required OfferedFile expected,
  required bool Function() isCancelled,
  required void Function(int byteCount) onBytesWritten,
}) async {
  final file = await createUniqueIncomingFile(saveDirectory, expected.name);
  final output = await file.open(mode: FileMode.writeOnly);
  final sink = _VerifyingFileSink(output, expected.sizeBytes, onBytesWritten);
  try {
    // Awaiting each batch pauses the upload, so a slow disk can't fill memory.
    await for (final chunk in body) {
      if (isCancelled()) {
        throw const TransferException(TransferFailure.cancelled);
      }
      await sink.add(chunk);
    }
    await sink.flush();
    // A cancel can land after the last chunk; it must still win.
    if (isCancelled()) {
      throw const TransferException(TransferFailure.cancelled);
    }
    if (!sink.isCompleteAndIntact) {
      throw const TransferException(TransferFailure.corrupted);
    }
    await output.close();
    return file;
  } on Object {
    await output.close();
    await file.delete();
    rethrow;
  }
}

/// Splits the body into file bytes and checksum, hashing as it writes.
class _VerifyingFileSink {
  new(this._output, this._fileBytes, this._onBytesWritten);

  final RandomAccessFile _output;
  final int _fileBytes;
  final void Function(int byteCount) _onBytesWritten;
  final _hasher = Xxh64Accumulator();
  final _batch = BytesBuilder(copy: false);
  final _checksum = BytesBuilder();
  int _fileBytesSeen = 0;

  bool get isCompleteAndIntact =>
      _fileBytesSeen == _fileBytes &&
      _checksum.length == uploadChecksumBytes &&
      decodeUploadChecksum(_checksum.toBytes()) == _hasher.finish();

  Future<void> add(List<int> chunk) async {
    final bytes = chunk is Uint8List ? chunk : Uint8List.fromList(chunk);
    final fileSlice = (_fileBytes - _fileBytesSeen).clamp(0, bytes.length);
    if (fileSlice > 0) {
      final fileBytes = Uint8List.sublistView(bytes, 0, fileSlice);
      _fileBytesSeen += fileSlice;
      _hasher.add(fileBytes);
      _batch.add(fileBytes);
    }
    if (fileSlice < bytes.length) {
      _checksum.add(Uint8List.sublistView(bytes, fileSlice));
      if (_checksum.length > uploadChecksumBytes) {
        throw const TransferException(TransferFailure.corrupted);
      }
    }
    if (_batch.length >= _writeBatchBytes) await flush();
  }

  Future<void> flush() async {
    if (_batch.isEmpty) return;
    final bytes = _batch.takeBytes();
    await _output.writeFrom(bytes);
    _onBytesWritten(bytes.length);
  }
}
