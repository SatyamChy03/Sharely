import 'dart:io';
import 'dart:typed_data';

import 'package:sharely_core/src/protocol/protocol_message.dart';
import 'package:sharely_core/src/security/safe_file_creator.dart';
import 'package:sharely_core/src/transfer/guarded_stream.dart';
import 'package:sharely_core/src/transfer/transfer_exception.dart';
import 'package:sharely_core/src/transfer/upload_checksum.dart';
import 'package:sharely_core/src/transfer/xxh64_accumulator.dart';

// Network chunks are small; one disk write per chunk wastes most of the time.
const int _writeBatchBytes = 4 << 20;

/// One incoming file on disk, filled by one or more requests.
///
/// Each request body is the file's remaining bytes followed by the checksum
/// of the whole file. A body that breaks off leaves the bytes received so
/// far in place, so the next request continues from [bytesWritten].
class PartialIncomingFile {
  new _(this.file, this.expected);

  /// Creates the empty file in [saveDirectory] under a safe, unused name.
  static Future<PartialIncomingFile> create(
    Directory saveDirectory,
    OfferedFile expected,
  ) async {
    final file = await createUniqueIncomingFile(saveDirectory, expected.name);
    return PartialIncomingFile._(file, expected);
  }

  final File file;
  final OfferedFile expected;
  final _hasher = Xxh64Accumulator();
  int _bytesWritten = 0;
  bool _isDiscarded = false;

  /// Bytes safely on disk, which is where a resumed request must start.
  int get bytesWritten => _bytesWritten;

  /// Writes one request's [body]; returns once the file is complete and its
  /// checksum matches.
  ///
  /// Throws [TransferInterrupted] when the body broke off (the file is
  /// kept), or a [TransferException] or [FileSystemException] when the file
  /// can't be completed (the file is deleted).
  Future<void> append(
    Stream<List<int>> body, {
    required bool Function() isCancelled,
    required void Function(int byteCount) onBytesWritten,
  }) async {
    final output = await file.open(mode: FileMode.writeOnlyAppend);
    final batch = BytesBuilder(copy: false);
    final checksum = BytesBuilder();

    Future<void> flush() async {
      if (batch.isEmpty) return;
      final bytes = batch.takeBytes();
      await output.writeFrom(bytes);
      _bytesWritten += bytes.length;
      onBytesWritten(bytes.length);
    }

    try {
      // Awaiting each batch pauses the sender, so a slow disk can't fill
      // memory.
      await for (final chunk in body) {
        if (isCancelled()) {
          throw const TransferException(TransferFailure.cancelled);
        }
        _split(chunk, batch, checksum);
        if (batch.length >= _writeBatchBytes) await flush();
      }
      await flush();
      // A cancel can land after the last chunk; it must still win.
      if (isCancelled()) {
        throw const TransferException(TransferFailure.cancelled);
      }
      _verify(checksum);
      await output.close();
    } on TransferException {
      await output.close();
      await discard();
      rethrow;
    } on FileSystemException {
      await output.close();
      await discard();
      rethrow;
    } on Object {
      // The network gave out. Keep what arrived, so it isn't sent twice.
      await _keepPartial(output, flush);
      throw const TransferInterrupted();
    }
  }

  /// Deletes the file; safe to call more than once.
  Future<void> discard() async {
    if (_isDiscarded) return;
    _isDiscarded = true;
    try {
      await file.delete();
    } on PathNotFoundException {
      // Already gone, which is all that was wanted.
    }
  }

  /// Sorts [chunk] into file bytes (hashed and queued) and checksum bytes.
  void _split(List<int> chunk, BytesBuilder batch, BytesBuilder checksum) {
    final bytes = chunk is Uint8List ? chunk : Uint8List.fromList(chunk);
    final queued = _bytesWritten + batch.length;
    final fileSlice = (expected.sizeBytes - queued).clamp(0, bytes.length);
    if (fileSlice > 0) {
      final fileBytes = Uint8List.sublistView(bytes, 0, fileSlice);
      _hasher.add(fileBytes);
      batch.add(fileBytes);
    }
    if (fileSlice == bytes.length) return;
    checksum.add(Uint8List.sublistView(bytes, fileSlice));
    if (checksum.length > uploadChecksumBytes) {
      throw const TransferException(TransferFailure.corrupted);
    }
  }

  void _verify(BytesBuilder checksum) {
    final isIntact =
        _bytesWritten == expected.sizeBytes &&
        checksum.length == uploadChecksumBytes &&
        decodeUploadChecksum(checksum.toBytes()) == _hasher.finish();
    if (!isIntact) throw const TransferException(TransferFailure.corrupted);
  }

  // Bytes already hashed must reach the disk, or the checksum and the file
  // would disagree after a resume.
  Future<void> _keepPartial(
    RandomAccessFile output,
    Future<void> Function() flush,
  ) async {
    try {
      await flush();
      await output.close();
    } on FileSystemException {
      await output.close().catchError((Object _) => output);
      await discard();
      rethrow;
    }
  }
}
