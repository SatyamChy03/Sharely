// Core runs only on native platforms, where int is a full 64-bit integer.
// ignore_for_file: avoid_js_rounded_ints

import 'dart:typed_data';

const _prime1 = 0x9E3779B185EBCA87;
const _prime2 = 0xC2B2AE3D27D4EB4F;
const _prime3 = 0x165667B19E3779F9;
const _prime4 = 0x85EBCA77C2B2AE63;
const _prime5 = 0x27D4EB2F165667C5;
const _stripeBytes = 32;

/// XXH64 (seed 0) of a byte stream, fed chunk by chunk.
///
/// Used to catch corruption, not tampering: it is many times faster than
/// SHA-256 in Dart, and an attacker who can rewrite bytes could rewrite
/// either digest anyway. Dart `int` arithmetic wraps at 64 bits, as XXH64
/// expects.
class Xxh64Accumulator {
  int _lane1 = _prime1 + _prime2;
  int _lane2 = _prime2;
  int _lane3 = 0;
  int _lane4 = -_prime1;
  int _totalBytes = 0;
  final _pending = Uint8List(_stripeBytes);
  late final _pendingView = ByteData.sublistView(_pending);
  int _pendingBytes = 0;

  void add(List<int> chunk) {
    final bytes = chunk is Uint8List ? chunk : Uint8List.fromList(chunk);
    _totalBytes += bytes.length;
    var offset = 0;
    if (_pendingBytes > 0) {
      offset = _fillPending(bytes);
      if (_pendingBytes < _stripeBytes) return;
      _consumeStripes(_pendingView, 0, _stripeBytes);
      _pendingBytes = 0;
    }
    final view = ByteData.sublistView(bytes);
    final stripesEnd =
        offset + (bytes.length - offset) ~/ _stripeBytes * _stripeBytes;
    _consumeStripes(view, offset, stripesEnd);
    _pending.setRange(0, bytes.length - stripesEnd, bytes, stripesEnd);
    _pendingBytes = bytes.length - stripesEnd;
  }

  /// The 64-bit digest; call once, after the last [add].
  int finish() {
    var hash = _totalBytes >= _stripeBytes ? _mergeLanes() : _prime5;
    hash += _totalBytes;
    var offset = 0;
    for (; offset + 8 <= _pendingBytes; offset += 8) {
      hash ^= _round(0, _pendingView.getUint64(offset, Endian.little));
      hash = _rotateLeft(hash, 27) * _prime1 + _prime4;
    }
    if (offset + 4 <= _pendingBytes) {
      hash ^= _pendingView.getUint32(offset, Endian.little) * _prime1;
      hash = _rotateLeft(hash, 23) * _prime2 + _prime3;
      offset += 4;
    }
    for (; offset < _pendingBytes; offset++) {
      hash ^= _pending[offset] * _prime5;
      hash = _rotateLeft(hash, 11) * _prime1;
    }
    return _avalanche(hash);
  }

  int _fillPending(Uint8List bytes) {
    final taken = (_stripeBytes - _pendingBytes).clamp(0, bytes.length);
    _pending.setRange(_pendingBytes, _pendingBytes + taken, bytes);
    _pendingBytes += taken;
    return taken;
  }

  void _consumeStripes(ByteData view, int start, int end) {
    var lane1 = _lane1;
    var lane2 = _lane2;
    var lane3 = _lane3;
    var lane4 = _lane4;
    for (var offset = start; offset < end; offset += _stripeBytes) {
      lane1 = _round(lane1, view.getUint64(offset, Endian.little));
      lane2 = _round(lane2, view.getUint64(offset + 8, Endian.little));
      lane3 = _round(lane3, view.getUint64(offset + 16, Endian.little));
      lane4 = _round(lane4, view.getUint64(offset + 24, Endian.little));
    }
    _lane1 = lane1;
    _lane2 = lane2;
    _lane3 = lane3;
    _lane4 = lane4;
  }

  int _mergeLanes() {
    var hash =
        _rotateLeft(_lane1, 1) +
        _rotateLeft(_lane2, 7) +
        _rotateLeft(_lane3, 12) +
        _rotateLeft(_lane4, 18);
    for (final lane in [_lane1, _lane2, _lane3, _lane4]) {
      hash = (hash ^ _round(0, lane)) * _prime1 + _prime4;
    }
    return hash;
  }
}

int _round(int accumulator, int input) =>
    _rotateLeft(accumulator + input * _prime2, 31) * _prime1;

int _rotateLeft(int value, int bits) =>
    (value << bits) | (value >>> (64 - bits));

int _avalanche(int hash) {
  var mixed = (hash ^ (hash >>> 33)) * _prime2;
  mixed = (mixed ^ (mixed >>> 29)) * _prime3;
  return mixed ^ (mixed >>> 32);
}
