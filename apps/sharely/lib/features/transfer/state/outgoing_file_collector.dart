import 'dart:io';

import 'package:sharely_core/sharely_core.dart';

/// Turns chosen or dropped paths into files to offer; a folder contributes
/// every file inside it.
///
/// Stops one past [maxFiles], which is enough for the offer to be refused
/// without walking the rest of a huge folder. Throws [FileSystemException]
/// when something can't be read.
Future<List<OutgoingFile>> collectOutgoingFiles(
  Iterable<String> paths, {
  int maxFiles = ProtocolLimits.maxFilesPerOffer,
}) async {
  final files = <OutgoingFile>[];
  for (final path in paths) {
    await for (final file in _filesAt(path)) {
      files.add(await OutgoingFile.fromPath(file.path));
      if (files.length > maxFiles) return files;
    }
  }
  return files;
}

Stream<File> _filesAt(String path) async* {
  if (!FileSystemEntity.isDirectorySync(path)) {
    yield File(path);
    return;
  }
  // Links inside a folder are skipped: they can loop or point outside it.
  final entries = Directory(path).list(recursive: true, followLinks: false);
  await for (final entry in entries) {
    if (entry is File) yield entry;
  }
}
