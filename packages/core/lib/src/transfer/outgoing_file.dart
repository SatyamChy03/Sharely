import 'dart:io';

import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
import 'package:sharely_core/src/transfer/mime_types.dart';

/// Opens a read of the file's bytes; called once per upload.
typedef OpenFileRead = Stream<List<int>> Function();

/// A local file this device is about to offer.
@immutable
final class OutgoingFile {
  const new({
    required this.name,
    required this.sizeBytes,
    required this.mimeType,
    required this.openRead,
  });

  /// Reads the size from disk; [name] defaults to the file's own name.
  static Future<OutgoingFile> fromPath(String path, {String? name}) async {
    final file = File(path);
    final displayName = name ?? p.basename(path);
    return OutgoingFile(
      name: displayName,
      sizeBytes: await file.length(),
      mimeType: guessMimeType(displayName),
      openRead: file.openRead,
    );
  }

  final String name;
  final int sizeBytes;
  final String mimeType;

  /// A byte source rather than a path: Android pickers may hand back
  /// `content://` URIs that have no file path at all.
  final OpenFileRead openRead;
}
