import 'dart:io';

import 'package:sharely_core/src/protocol/protocol_message.dart';
import 'package:sharely_core/src/security/safe_file_creator.dart';
import 'package:sharely_core/src/transfer/sha256_accumulator.dart';
import 'package:sharely_core/src/transfer/transfer_exception.dart';

/// Streams one upload to a new file in [saveDirectory], chunk by chunk.
///
/// The file is kept only if its size and SHA-256 match [expected]; on any
/// failure the partial file is deleted and the error is rethrown.
Future<File> writeIncomingFile({
  required Stream<List<int>> body,
  required Directory saveDirectory,
  required OfferedFile expected,
  required bool Function() isCancelled,
  required void Function(int byteCount) onBytesWritten,
}) async {
  final file = await createUniqueIncomingFile(saveDirectory, expected.name);
  final hasher = Sha256Accumulator();
  final output = await file.open(mode: FileMode.writeOnly);
  var bytesReceived = 0;
  try {
    // Awaiting each write pauses the upload, so a slow disk can't fill memory.
    await for (final chunk in body) {
      if (isCancelled()) {
        throw const TransferException(TransferFailure.cancelled);
      }
      bytesReceived += chunk.length;
      if (bytesReceived > expected.sizeBytes) {
        throw const TransferException(TransferFailure.corrupted);
      }
      hasher.add(chunk);
      await output.writeFrom(chunk);
      onBytesWritten(chunk.length);
    }
    // A cancel can land after the last chunk; it must still win.
    if (isCancelled()) {
      throw const TransferException(TransferFailure.cancelled);
    }
    if (bytesReceived != expected.sizeBytes ||
        hasher.finish() != expected.sha256) {
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
