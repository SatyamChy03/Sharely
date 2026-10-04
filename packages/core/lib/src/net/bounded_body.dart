import 'dart:convert';

import 'package:sharely_core/src/protocol/protocol_exception.dart';

/// Reads a UTF-8 body but stops as soon as it passes [maxBytes], so a peer
/// cannot exhaust memory with an endless request or response.
Future<String> readBoundedUtf8(Stream<List<int>> body, int maxBytes) async {
  final bytes = <int>[];
  await for (final chunk in body) {
    if (bytes.length + chunk.length > maxBytes) {
      throw const ProtocolException('Body is too large');
    }
    bytes.addAll(chunk);
  }
  try {
    return utf8.decode(bytes);
  } on FormatException {
    throw const ProtocolException('Body is not valid UTF-8');
  }
}
