import 'dart:convert';

import 'package:sharely_core/sharely_core.dart';
import 'package:test/test.dart';

const _pairedDevicesKey = 'sharely.pairedDevices';

PairedDevice _phone({String deviceId = 'phone_0123456789abc'}) {
  return PairedDevice(
    deviceId: deviceId,
    deviceName: "Satyam's Phone",
    platform: DevicePlatform.android,
    authToken: 'auth_0123456789abcdef0123456789abcdef',
    pairedAt: DateTime.utc(2026, 10, 5, 9, 30),
  );
}

Map<String, Object?> _validRecord() => {
  'deviceId': 'phone_0123456789abc',
  'name': 'Phone',
  'platform': 'android',
  'authToken': 'auth_0123456789abcdef',
  'pairedAt': 1791000000000,
};

String _storedList(List<Object?> devices, {Object? version = 1}) =>
    jsonEncode({'version': version, 'devices': devices});

// Each entry is stored text that must be rejected rather than trusted.
final _corruptedStores = <String, String>{
  'not JSON': '{oops',
  'a JSON list': '[]',
  'an unknown version': _storedList([], version: 2),
  'an extra top-level field': jsonEncode({
    'version': 1,
    'devices': <Object?>[],
    'admin': true,
  }),
  'an extra device field': _storedList([
    {..._validRecord(), 'trusted': 'always'},
  ]),
  'a malformed device id': _storedList([
    {..._validRecord(), 'deviceId': '../../etc'},
  ]),
  'a short auth token': _storedList([
    {..._validRecord(), 'authToken': 'short'},
  ]),
  'an unknown platform': _storedList([
    {..._validRecord(), 'platform': 'toaster'},
  ]),
  'a control character in the name': _storedList([
    {..._validRecord(), 'name': 'Phone\u0007'},
  ]),
  'a far-future pairing date': _storedList([
    {..._validRecord(), 'pairedAt': 9999999999999},
  ]),
  'too many devices': _storedList(
    List.filled(maxStoredPairedDevices + 1, _validRecord()),
  ),
};

void main() {
  late MemorySecretStore secrets;
  late TrustStore store;

  setUp(() {
    secrets = MemorySecretStore();
    store = TrustStore(secrets);
  });

  group('device id', () {
    test('is created once and then stays the same', () async {
      final first = await store.loadOrCreateDeviceId();
      final second = await TrustStore(secrets).loadOrCreateDeviceId();

      expect(isValidProtocolId(first), isTrue);
      expect(second, first);
    });

    test('a corrupted stored id is replaced with a fresh one', () async {
      await secrets.write('sharely.deviceId', 'bad id!');

      final deviceId = await store.loadOrCreateDeviceId();

      expect(isValidProtocolId(deviceId), isTrue);
      expect(await secrets.read('sharely.deviceId'), deviceId);
    });
  });

  group('paired devices', () {
    test('start empty', () async {
      expect(await store.loadPairedDevices(), isEmpty);
    });

    test('round-trip with every field intact', () async {
      final phone = _phone();
      await store.savePairedDevices([phone]);

      final loaded = (await store.loadPairedDevices()).single;

      expect(loaded.deviceId, phone.deviceId);
      expect(loaded.deviceName, phone.deviceName);
      expect(loaded.platform, phone.platform);
      expect(loaded.authToken, phone.authToken);
      expect(loaded.pairedAt, phone.pairedAt);
    });

    test('can be forgotten', () async {
      await store.savePairedDevices([_phone()]);
      await store.forgetPairedDevices();

      expect(await store.loadPairedDevices(), isEmpty);
    });

    test('refuse to save more than the limit', () {
      final tooMany = [
        for (var i = 0; i <= maxStoredPairedDevices; i++)
          _phone(deviceId: 'phone_${i.toString().padLeft(16, '0')}'),
      ];

      expect(() => store.savePairedDevices(tooMany), throwsArgumentError);
    });

    for (final MapEntry(key: description, value: stored)
        in _corruptedStores.entries) {
      test('reject a store with $description', () async {
        await secrets.write(_pairedDevicesKey, stored);

        await expectLater(
          store.loadPairedDevices(),
          throwsA(isA<TrustStoreException>()),
        );
      });
    }
  });
}
