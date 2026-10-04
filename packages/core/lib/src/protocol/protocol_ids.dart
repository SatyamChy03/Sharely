import 'package:sharely_core/src/protocol/protocol_limits.dart';

final _idPattern = RegExp(r'^[A-Za-z0-9_-]+$');

/// Ids (devices, transfers, tokens) are URL-safe and 16 to 64 characters.
bool isValidProtocolId(String value) {
  return value.length >= ProtocolLimits.minIdChars &&
      value.length <= ProtocolLimits.maxIdChars &&
      _idPattern.hasMatch(value);
}
