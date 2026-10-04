import 'package:sharely_core/src/protocol/protocol_exception.dart';
import 'package:sharely_core/src/protocol/protocol_limits.dart';

final _controlCharacters = RegExp(r'[\x00-\x1F\x7F]');
final _idPattern = RegExp(r'^[A-Za-z0-9_-]+$');

/// Typed, validating access to a decoded JSON object from an untrusted peer.
class JsonFields {
  const new(this._json);

  final Map<String, Object?> _json;

  /// Rejects any key outside [allowedKeys], so unknown data never slips in.
  void requireOnlyKeys(Set<String> allowedKeys) {
    for (final key in _json.keys) {
      if (!allowedKeys.contains(key)) {
        throw const ProtocolException('Message has an unexpected field');
      }
    }
  }

  String string(
    String key, {
    required int maxLength,
    int minLength = 1,
    bool allowControlCharacters = false,
  }) {
    final value = _json[key];
    if (value is! String) throw ProtocolException('"$key" must be a string');
    if (value.length < minLength || value.length > maxLength) {
      throw ProtocolException('"$key" has an invalid length');
    }
    if (!allowControlCharacters && _controlCharacters.hasMatch(value)) {
      throw ProtocolException('"$key" contains control characters');
    }
    return value;
  }

  String id(String key) {
    final value = string(key, maxLength: ProtocolLimits.maxIdChars);
    if (value.length < ProtocolLimits.minIdChars ||
        !_idPattern.hasMatch(value)) {
      throw ProtocolException('"$key" is not a valid id');
    }
    return value;
  }

  int integer(String key, {required int min, required int max}) {
    final value = _json[key];
    if (value is! int) throw ProtocolException('"$key" must be an integer');
    if (value < min || value > max) {
      throw ProtocolException('"$key" is out of range');
    }
    return value;
  }

  List<JsonFields> objectList(
    String key, {
    required int minLength,
    required int maxLength,
  }) {
    final value = _json[key];
    if (value is! List<Object?>) {
      throw ProtocolException('"$key" must be a list');
    }
    if (value.length < minLength || value.length > maxLength) {
      throw ProtocolException('"$key" has an invalid number of items');
    }
    return [
      for (final item in value)
        if (item is Map<String, Object?>)
          JsonFields(item)
        else
          throw ProtocolException('"$key" items must be objects'),
    ];
  }
}
