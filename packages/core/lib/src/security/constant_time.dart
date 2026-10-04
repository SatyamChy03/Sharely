import 'dart:convert';

/// Compares two secrets in time that does not depend on where they differ,
/// so an attacker cannot guess a token one character at a time.
bool constantTimeEquals(String a, String b) {
  final left = utf8.encode(a);
  final right = utf8.encode(b);
  var difference = left.length ^ right.length;
  final length = left.length > right.length ? left.length : right.length;
  for (var index = 0; index < length; index++) {
    final leftByte = index < left.length ? left[index] : 0;
    final rightByte = index < right.length ? right[index] : 0;
    difference |= leftByte ^ rightByte;
  }
  return difference == 0;
}
