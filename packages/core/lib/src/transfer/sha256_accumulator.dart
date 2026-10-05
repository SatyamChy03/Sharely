import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Hashes a file chunk by chunk, so it never has to fit in memory.
class Sha256Accumulator {
  new() {
    _input = sha256.startChunkedConversion(_capture);
  }

  final _capture = _DigestCapture();
  late final ByteConversionSink _input;

  void add(List<int> chunk) => _input.add(chunk);

  /// Lowercase hex, the form offers carry.
  String finish() {
    _input.close();
    return _capture.value.toString();
  }
}

class _DigestCapture implements Sink<Digest> {
  Digest? _digest;

  Digest get value => _digest ?? (throw StateError('Hash not finished'));

  @override
  void add(Digest digest) => _digest = digest;

  @override
  void close() {}
}
