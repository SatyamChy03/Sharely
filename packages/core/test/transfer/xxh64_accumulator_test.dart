import 'dart:typed_data';

import 'package:sharely_core/src/transfer/upload_checksum.dart';
import 'package:sharely_core/src/transfer/xxh64_accumulator.dart';
import 'package:test/test.dart';

String _digestHex(List<List<int>> chunks) {
  final hasher = Xxh64Accumulator();
  chunks.forEach(hasher.add);
  // Dart ints are signed, so format the big-endian bytes rather than the int.
  return encodeUploadChecksum(hasher.finish())
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
}

List<int> _pattern(int length) => [for (var i = 0; i < length; i++) i % 251];

void main() {
  // Expected values come from the reference xxHash library (XXH64, seed 0).
  final referenceDigests = {
    'empty input': (<int>[], 'ef46db3751d8e999'),
    '"a"': ('a'.codeUnits, 'd24ec4f1a98c6e5b'),
    '"abc"': ('abc'.codeUnits, '44bc2cf5ad770999'),
    '"Sharely"': ('Sharely'.codeUnits, 'bad06462b008f805'),
    'one byte short of a stripe': (_pattern(31), 'c346d2b59b4d8ee1'),
    'exactly one stripe': (_pattern(32), 'cbf59c5116ff32b4'),
    '1000 bytes': (_pattern(1000), 'f306f04aa88b54d3'),
  };
  for (final MapEntry(key: description, value: (bytes, digest))
      in referenceDigests.entries) {
    test('matches the reference digest for $description', () {
      expect(_digestHex([bytes]), digest);
    });
  }

  test('gives the same digest however the input is split', () {
    final bytes = _pattern(1000);
    final whole = _digestHex([bytes]);

    for (final chunkSize in [1, 3, 7, 31, 32, 33, 100, 999]) {
      final chunks = [
        for (var start = 0; start < bytes.length; start += chunkSize)
          bytes.sublist(start, (start + chunkSize).clamp(0, bytes.length)),
      ];
      expect(_digestHex(chunks), whole, reason: 'chunks of $chunkSize');
    }
  });

  test('accepts plain lists as well as typed data', () {
    expect(
      _digestHex([Uint8List.fromList(_pattern(100))]),
      _digestHex([_pattern(100)]),
    );
  });

  test('the upload checksum round-trips through its eight bytes', () {
    final hasher = Xxh64Accumulator()..add(_pattern(1000));
    final digest = hasher.finish();

    final encoded = encodeUploadChecksum(digest);

    expect(encoded, hasLength(uploadChecksumBytes));
    expect(encoded.first, 0xf3, reason: 'big-endian, like the hex form');
    expect(decodeUploadChecksum(encoded), digest);
  });
}
