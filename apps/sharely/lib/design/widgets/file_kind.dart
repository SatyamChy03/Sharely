import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// What a file is, as far as its thumbnail is concerned.
enum FileKind {
  image,
  video,
  pdf,
  audio,
  archive,
  app,
  document,
  link,
  text,
  folder;

  /// Guesses the kind from the extension; anything unknown is a document.
  factory fromName(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot < 0) return FileKind.document;
    return _kindByExtension[fileName.substring(dot + 1).toLowerCase()] ??
        FileKind.document;
  }

  IconData get glyph => switch (this) {
    FileKind.image => LucideIcons.image,
    FileKind.video => LucideIcons.video,
    FileKind.pdf || FileKind.document => LucideIcons.fileText,
    FileKind.audio => LucideIcons.music,
    FileKind.archive => LucideIcons.fileArchive,
    FileKind.app => LucideIcons.package,
    FileKind.link => LucideIcons.link,
    FileKind.text => LucideIcons.clipboardList,
    FileKind.folder => LucideIcons.folder,
  };
}

const _kindByExtension = <String, FileKind>{
  'jpg': FileKind.image,
  'jpeg': FileKind.image,
  'png': FileKind.image,
  'gif': FileKind.image,
  'webp': FileKind.image,
  'heic': FileKind.image,
  'bmp': FileKind.image,
  'svg': FileKind.image,
  'mp4': FileKind.video,
  'mkv': FileKind.video,
  'mov': FileKind.video,
  'webm': FileKind.video,
  'avi': FileKind.video,
  '3gp': FileKind.video,
  'pdf': FileKind.pdf,
  'mp3': FileKind.audio,
  'wav': FileKind.audio,
  'm4a': FileKind.audio,
  'flac': FileKind.audio,
  'ogg': FileKind.audio,
  'zip': FileKind.archive,
  'rar': FileKind.archive,
  '7z': FileKind.archive,
  'tar': FileKind.archive,
  'gz': FileKind.archive,
  'apk': FileKind.app,
  'exe': FileKind.app,
  'msi': FileKind.app,
  'deb': FileKind.app,
};
