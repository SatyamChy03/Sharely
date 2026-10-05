import 'package:path/path.dart' as p;

const _fallbackMimeType = 'application/octet-stream';

const _mimeTypesByExtension = {
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.png': 'image/png',
  '.gif': 'image/gif',
  '.webp': 'image/webp',
  '.heic': 'image/heic',
  '.mp4': 'video/mp4',
  '.mov': 'video/quicktime',
  '.mkv': 'video/x-matroska',
  '.mp3': 'audio/mpeg',
  '.m4a': 'audio/mp4',
  '.pdf': 'application/pdf',
  '.txt': 'text/plain',
  '.zip': 'application/zip',
  '.apk': 'application/vnd.android.package-archive',
};

/// A display hint only; the receiver never trusts it for anything else.
String guessMimeType(String fileName) =>
    _mimeTypesByExtension[p.extension(fileName).toLowerCase()] ??
    _fallbackMimeType;
