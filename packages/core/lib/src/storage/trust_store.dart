import 'package:sharely_core/src/pairing/paired_device.dart';
import 'package:sharely_core/src/protocol/protocol_exception.dart';
import 'package:sharely_core/src/protocol/protocol_ids.dart';
import 'package:sharely_core/src/security/secure_id.dart';
import 'package:sharely_core/src/storage/paired_device_records.dart';
import 'package:sharely_core/src/storage/secret_store.dart';
import 'package:sharely_core/src/storage/trust_store_exception.dart';

/// This device's lasting identity and the devices it trusts.
class TrustStore {
  const new(this._secrets);

  final SecretStore _secrets;

  static const _deviceIdKey = 'sharely.deviceId';
  static const _pairedDevicesKey = 'sharely.pairedDevices';

  /// The id other devices know this one by, created on first launch.
  Future<String> loadOrCreateDeviceId() async {
    final storedId = await _secrets.read(_deviceIdKey);
    if (storedId != null && isValidProtocolId(storedId)) return storedId;
    final newId = generateSecureId();
    await _secrets.write(_deviceIdKey, newId);
    return newId;
  }

  /// Throws [TrustStoreException] when the stored list fails validation.
  Future<List<PairedDevice>> loadPairedDevices() async {
    final stored = await _secrets.read(_pairedDevicesKey);
    if (stored == null) return const [];
    try {
      return decodePairedDevices(stored);
    } on ProtocolException {
      throw const TrustStoreException('Stored paired devices are unreadable');
    }
  }

  Future<void> savePairedDevices(List<PairedDevice> devices) =>
      _secrets.write(_pairedDevicesKey, encodePairedDevices(devices));

  Future<void> forgetPairedDevices() => _secrets.delete(_pairedDevicesKey);
}
