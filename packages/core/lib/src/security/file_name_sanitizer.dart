import 'dart:convert';

import 'package:path/path.dart' as p;

const _fallbackName = 'file';
// Headroom under the common 255-byte limit for a " (999)" duplicate suffix.
const _maxNameBytes = 240;
const _maxExtensionChars = 16;

final _pathSeparators = RegExp(r'[/\\]');
// Includes the C1 controls and the Unicode line breaks, which terminals
// and file managers may act on or render as nothing.
final _forbiddenCharacters = RegExp(
  r'[<>:"|?*\x00-\x1F\x7F-\x9F\u2028\u2029]',
  unicode: true,
);
// Bidi controls can disguise "gpj.exe" as "exe.jpg" in file managers.
final _bidiControls = RegExp(
  r'[\u061C\u200E\u200F\u202A-\u202E\u2066-\u2069]',
  unicode: true,
);
final _edgeDotsAndSpaces = RegExp(r'^[.\s]+|[.\s]+$');
final _windowsReservedStem = RegExp(
  r'^(con|prn|aux|nul|com[1-9]|lpt[1-9])$',
  caseSensitive: false,
);

/// Turns an untrusted peer-supplied name into a single safe file name.
///
/// Keeps only the last path segment, so traversal like `../../x` is impossible.
String sanitizeFileName(String requestedName) {
  final lastSegment = requestedName
      .split(_pathSeparators)
      .lastWhere((segment) => segment.isNotEmpty, orElse: () => '');
  final cleaned = lastSegment
      .replaceAll(_bidiControls, '')
      .replaceAll(_forbiddenCharacters, '_')
      .replaceAll(_edgeDotsAndSpaces, '');
  if (cleaned.isEmpty) return _fallbackName;

  final stem = cleaned.split('.').first;
  final safeName = _windowsReservedStem.hasMatch(stem) ? '_$cleaned' : cleaned;
  return _truncateKeepingExtension(safeName, _maxNameBytes);
}

String _truncateKeepingExtension(String name, int maxBytes) {
  if (utf8.encode(name).length <= maxBytes) return name;
  var extension = p.extension(name);
  if (extension.length > _maxExtensionChars) extension = '';
  final stemBudget = maxBytes - utf8.encode(extension).length;
  final stem = name.substring(0, name.length - extension.length);
  final truncated = StringBuffer();
  var usedBytes = 0;
  for (final rune in stem.runes) {
    final character = String.fromCharCode(rune);
    final runeBytes = utf8.encode(character).length;
    if (usedBytes + runeBytes > stemBudget) break;
    truncated.write(character);
    usedBytes += runeBytes;
  }
  return '$truncated$extension';
}
