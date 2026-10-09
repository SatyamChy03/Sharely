import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sharely/features/pairing/state/local_identity.dart';
import 'package:sharely/features/pairing/state/paired_devices.dart';
import 'package:sharely/features/transfer/state/laptop_connection_controller.dart';
import 'package:sharely/features/transfer/state/laptop_connection_state.dart';
import 'package:sharely_core/sharely_core.dart';

import '../../support/test_tls.dart';

class _FixedPairedDevices extends PairedDevicesNotifier {
  new(this._devices);

  final List<PairedDevice> _devices;

  @override
  Future<List<PairedDevice>> build() async => _devices;

  @override
  Future<void> trust(PairedDevice device) async {
    state = AsyncData([device]);
  }
}

PairedDevice _laptop({DeviceEndpoint? endpoint}) => PairedDevice(
  deviceId: 'laptop_0123456789ab',
  deviceName: 'Laptop',
  platform: DevicePlatform.windows,
  authToken: 'auth_0123456789abcdef',
  pairedAt: DateTime.utc(2026, 10, 5),
  endpoint: endpoint,
);

Future<ProviderContainer> _phoneWith(
  List<PairedDevice> devices, {
  ControlConnector? connector,
  LaptopAddressLookup? addressLookup,
}) async {
  final container = ProviderContainer(
    overrides: [
      pairedDevicesProvider.overrideWith(() => _FixedPairedDevices(devices)),
      localHelloProvider.overrideWith(
        (ref) async => const HelloMessage(
          deviceId: 'phone_0123456789abc',
          deviceName: 'Phone',
          platform: DevicePlatform.android,
        ),
      ),
      if (connector != null)
        controlConnectorProvider.overrideWithValue(connector),
      laptopAddressLookupProvider.overrideWithValue(
        addressLookup ?? (laptop, localDeviceId) async => null,
      ),
    ],
  );
  addTearDown(container.dispose);
  await container.read(pairedDevicesProvider.future);
  return container;
}

void main() {
  test('with nothing paired there is nothing to connect to', () async {
    final phone = await _phoneWith(const []);

    expect(phone.read(laptopConnectionProvider), isA<LaptopNotPaired>());
  });

  test('a pairing without an address asks for one more scan', () async {
    final phone = await _phoneWith([_laptop()]);

    expect(phone.read(laptopConnectionProvider), isA<LaptopNeedsRepairing>());
  });

  test('an unreachable laptop is reported and retried on demand', () async {
    var attempts = 0;
    final phone = await _phoneWith(
      [
        _laptop(
          endpoint: DeviceEndpoint.parse(
            host: '192.168.1.24',
            port: 53891,
            certFingerprint: testFingerprint,
          ),
        ),
      ],
      connector: (endpoint, authHeaders) async {
        attempts++;
        expect(authHeaders['x-sharely-device'], 'phone_0123456789abc');
        throw const TransferException(TransferFailure.unreachable);
      },
    );
    final states = <LaptopConnectionState>[];
    phone.listen(
      laptopConnectionProvider,
      (_, next) => states.add(next),
      fireImmediately: true,
    );
    await pumpEventQueue();

    phone.read(laptopConnectionProvider.notifier).retryNow();
    await pumpEventQueue();

    expect(attempts, 2);
    expect(states, [
      isA<LaptopConnecting>(),
      isA<LaptopUnreachable>(),
      isA<LaptopConnecting>(),
      isA<LaptopUnreachable>(),
    ]);
  });

  test('a laptop that moved is followed to its new address', () async {
    final oldEndpoint = DeviceEndpoint.parse(
      host: '172.25.8.25',
      port: 53891,
      certFingerprint: testFingerprint,
    );
    final newEndpoint = DeviceEndpoint.parse(
      host: '172.25.13.173',
      port: 53891,
      certFingerprint: testFingerprint,
    );
    final triedEndpoints = <DeviceEndpoint>[];
    final phone = await _phoneWith(
      [_laptop(endpoint: oldEndpoint)],
      connector: (endpoint, authHeaders) async {
        triedEndpoints.add(endpoint);
        throw const TransferException(TransferFailure.unreachable);
      },
      addressLookup: (laptop, localDeviceId) async {
        expect(localDeviceId, 'phone_0123456789abc');
        return newEndpoint;
      },
    );
    phone.listen(laptopConnectionProvider, (_, _) {}, fireImmediately: true);
    await pumpEventQueue();

    expect(triedEndpoints, [oldEndpoint, newEndpoint]);
    expect(
      phone.read(pairedDevicesProvider).value?.single.endpoint,
      newEndpoint,
    );
    expect(phone.read(laptopConnectionProvider), isA<LaptopUnreachable>());
  });
}
