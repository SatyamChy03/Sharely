import 'dart:convert';

import 'package:sharely_core/src/pairing/paired_device.dart';
import 'package:sharely_core/src/protocol/json_fields.dart';
import 'package:sharely_core/src/protocol/protocol_exception.dart';
import 'package:sharely_core/src/protocol/protocol_limits.dart';
import 'package:sharely_core/src/protocol/protocol_message.dart';

const int maxStoredPairedDevices = 32;
const _recordsVersion = 1;

// Year 2100: anything later means the record was tampered with or corrupted.
const _maxPairedAtMillis = 4102444800000;

/// Serialises paired devices, auth tokens included, for secure storage only.
String encodePairedDevices(List<PairedDevice> devices) {
  if (devices.length > maxStoredPairedDevices) {
    throw ArgumentError.value(devices.length, 'devices', 'Too many devices');
  }
  return jsonEncode({
    'version': _recordsVersion,
    'devices': [for (final device in devices) _encodeDevice(device)],
  });
}

/// Reads stored records with the same strictness as network input.
List<PairedDevice> decodePairedDevices(String stored) {
  final fields = JsonFields(decodeJsonObject(stored))
    ..requireOnlyKeys(const {'version', 'devices'});
  final version = fields.integer('version', min: 1, max: 1000);
  if (version != _recordsVersion) {
    throw const ProtocolException('Unsupported paired devices version');
  }
  final records = fields.objectList(
    'devices',
    minLength: 0,
    maxLength: maxStoredPairedDevices,
  );
  return List.unmodifiable(records.map(_decodeDevice));
}

Map<String, Object?> _encodeDevice(PairedDevice device) => {
  'deviceId': device.deviceId,
  'name': device.deviceName,
  'platform': device.platform.name,
  'authToken': device.authToken,
  'pairedAt': device.pairedAt.toUtc().millisecondsSinceEpoch,
};

PairedDevice _decodeDevice(JsonFields fields) {
  fields.requireOnlyKeys(const {
    'deviceId',
    'name',
    'platform',
    'authToken',
    'pairedAt',
  });
  final platform = DevicePlatform.fromWireName(
    fields.string('platform', maxLength: 16),
  );
  if (platform == null) throw const ProtocolException('Unknown platform');
  final pairedAtMillis = fields.integer(
    'pairedAt',
    min: 0,
    max: _maxPairedAtMillis,
  );
  return PairedDevice(
    deviceId: fields.id('deviceId'),
    deviceName: fields.string(
      'name',
      maxLength: ProtocolLimits.maxDeviceNameChars,
    ),
    platform: platform,
    authToken: fields.id('authToken'),
    pairedAt: DateTime.fromMillisecondsSinceEpoch(pairedAtMillis, isUtc: true),
  );
}
