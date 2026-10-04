import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sharely_core/src/security/file_name_sanitizer.dart';
import 'package:sharely_core/src/security/file_safety_exception.dart';

const _maxDuplicateAttempts = 1000;

/// Creates a new, empty file for an incoming transfer inside [saveDirectory].
///
/// Never overwrites: an existing name becomes "name (1).ext", "name (2).ext".
/// Exclusive create makes the existence check and creation one atomic step,
/// which also refuses to follow a symlink planted at the target path.
Future<File> createUniqueIncomingFile(
  Directory saveDirectory,
  String requestedName,
) async {
  final root = p.canonicalize(saveDirectory.path);
  final safeName = sanitizeFileName(requestedName);
  for (var attempt = 0; attempt < _maxDuplicateAttempts; attempt++) {
    final candidate = p.join(root, _numberedName(safeName, attempt));
    if (!p.isWithin(root, candidate)) {
      throw const FileSafetyException('Resolved path escapes save folder');
    }
    try {
      return await File(candidate).create(exclusive: true);
    } on PathExistsException {
      continue;
    }
  }
  throw const FileSafetyException('Too many files with the same name');
}

String _numberedName(String fileName, int attempt) {
  if (attempt == 0) return fileName;
  final extension = p.extension(fileName);
  final stem = p.basenameWithoutExtension(fileName);
  return '$stem ($attempt)$extension';
}
