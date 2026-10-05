import 'dart:io';

import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
import 'package:sharely_core/src/transfer/mime_types.dart';

/// A local file this device is about to offer.
@immutable
final class OutgoingFile {
  const new({
    required this.path,
    required this.name,
    required this.sizeBytes,
    required this.mimeType,
  });

  /// Reads the size from disk; [name] defaults to the file's own name.
  static Future<OutgoingFile> fromPath(String path, {String? name}) async {
    final displayName = name ?? p.basename(path);
    return OutgoingFile(
      path: path,
      name: displayName,
      sizeBytes: await File(path).length(),
      mimeType: guessMimeType(displayName),
    );
  }

  final String path;
  final String name;
  final int sizeBytes;
  final String mimeType;
}
