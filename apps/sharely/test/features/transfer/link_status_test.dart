import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sharely/app/storage/trust_store_provider.dart';
import 'package:sharely/features/pairing/state/local_identity.dart';
import 'package:sharely/features/pairing/state/paired_devices.dart';
import 'package:sharely/features/transfer/state/connected_phones.dart';
import 'package:sharely/features/transfer/state/laptop_connection_controller.dart';
import 'package:sharely/features/transfer/state/laptop_connection_state.dart';
import 'package:sharely/features/transfer/state/transfer_receiver_provider.dart';
import 'package:sharely/features/transfer/state/transfer_sender_provider.dart';
import 'package:sharely_core/sharely_core.dart';

import '../../support/test_tls.dart';

const _authToken = 'auth_0123456789abcdef0123456789abcdef';
const _phoneHello = HelloMessage(
  deviceId: 'phone_0123456789abc',
  deviceName: 'Phone',
  platform: DevicePlatform.android,
);
const _laptopHello = HelloMessage(
  deviceId: 'laptop_0123456789ab',
  deviceName: 'Laptop',
  platform: DevicePlatform.linux,
);
final PairedDevice _phoneRecord = PairedDevice.fromHello(
  _phoneHello,
  authToken: _authToken,
  pairedAt: DateTime.utc(2026, 10, 9),
);

Future<void> _eventually(bool Function() condition, {String? what}) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) fail('Never happened: $what');
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

void main() {
  late ProviderContainer laptop;
  late SharelyServer server;

  ControlHub hub() => laptop.read(transferReceiverProvider).hub;

  DeviceEndpoint endpoint() => DeviceEndpoint(
    host: server.address,
    port: server.port,
    certFingerprint: testIdentity.fingerprint,
  );

  setUp(() async {
    laptop = ProviderContainer(
      overrides: [
        trustStoreProvider.overrideWithValue(TrustStore(MemorySecretStore())),
      ],
    );
    server = await SharelyServer.start(
      address: InternetAddress.loopbackIPv4,
      preferredPort: 0,
      identity: testIdentity,
      pairingHandler: PairingRequestHandler(
        currentSession: () => null,
        localHello: _laptopHello,
        onPaired: (_) {},
      ),
      transfers: (
        receiver: laptop.read(transferReceiverProvider),
        sender: laptop.read(transferSenderProvider),
        findPairedDevice: (deviceId) =>
            deviceId == _phoneRecord.deviceId ? _phoneRecord : null,
      ),
    );
    addTearDown(() async {
      laptop.dispose();
      await server.stop();
    });
  });

  Future<ProviderContainer> startPhone() async {
    final phone = ProviderContainer(
      overrides: [
        trustStoreProvider.overrideWithValue(TrustStore(MemorySecretStore())),
        localHelloProvider.overrideWith((ref) async => _phoneHello),
      ],
    );
    addTearDown(phone.dispose);
    await phone
        .read(pairedDevicesProvider.notifier)
        .trust(
          PairedDevice.fromHello(
            _laptopHello,
            authToken: _authToken,
            pairedAt: DateTime.utc(2026, 10, 9),
            endpoint: endpoint(),
          ),
        );
    phone.listen(laptopConnectionProvider, (_, _) {});
    await _eventually(
      () => phone.read(laptopConnectionProvider) is LaptopConnected,
      what: 'the phone connecting',
    );
    await _eventually(() => hub().isConnected(_phoneHello.deviceId));
    return phone;
  }

  test('the laptop lists a phone that connected before it looked', () async {
    await startPhone();

    expect(laptop.read(connectedPhonesProvider), {_phoneHello.deviceId});
  });

  test('the laptop shows a closed phone as gone at once', () async {
    final phone = await startPhone();
    laptop.listen(connectedPhonesProvider, (_, _) {});
    final closed = Stopwatch()..start();

    phone.dispose();

    await _eventually(
      () => laptop.read(connectedPhonesProvider).isEmpty,
      what: 'the laptop noticing',
    );
    expect(closed.elapsed, lessThan(const Duration(seconds: 1)));
  });

  /// A laptop that accepts the link and then never answers, as one that
  /// already dropped a frozen phone looks from the phone's side.
  Future<DeviceEndpoint> startMuteLaptop() async {
    final mute = await HttpServer.bindSecure(
      InternetAddress.loopbackIPv4,
      0,
      testIdentity.createServerContext(),
    );
    addTearDown(() => mute.close(force: true));
    mute.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      socket.listen((_) {});
    });
    return DeviceEndpoint(
      host: mute.address,
      port: mute.port,
      certFingerprint: testIdentity.fingerprint,
    );
  }

  /// A phone whose first link goes to [first]; later ones reach the laptop.
  Future<ProviderContainer> startPhoneLinkedTo(DeviceEndpoint first) async {
    var links = 0;
    final phone = ProviderContainer(
      overrides: [
        trustStoreProvider.overrideWithValue(TrustStore(MemorySecretStore())),
        localHelloProvider.overrideWith((ref) async => _phoneHello),
        controlConnectorProvider.overrideWithValue(
          (_, authHeaders) => ControlConnection.connect(
            links++ == 0 ? first : endpoint(),
            authHeaders: authHeaders,
          ),
        ),
      ],
    );
    addTearDown(phone.dispose);
    await phone
        .read(pairedDevicesProvider.notifier)
        .trust(
          PairedDevice.fromHello(
            _laptopHello,
            authToken: _authToken,
            pairedAt: DateTime.utc(2026, 10, 9),
            endpoint: endpoint(),
          ),
        );
    phone.listen(laptopConnectionProvider, (_, _) {});
    await _eventually(
      () => phone.read(laptopConnectionProvider) is LaptopConnected,
      what: 'the first link',
    );
    return phone;
  }

  test('back on screen, a link that only looks open is replaced', () async {
    final phone = await startPhoneLinkedTo(await startMuteLaptop());
    expect(hub().isConnected(_phoneHello.deviceId), isFalse);

    phone.read(laptopConnectionProvider.notifier).ensureLinked();

    await _eventually(
      () => hub().isConnected(_phoneHello.deviceId),
      what: 'a working link to the laptop',
    );
    // The laptop sees the new link a moment before the phone adopts it.
    await _eventually(
      () => phone.read(laptopConnectionProvider) is LaptopConnected,
      what: 'the phone showing connected',
    );
  });

  test('back on screen, a link that answers is left alone', () async {
    final phone = await startPhone();
    final before =
        (phone.read(laptopConnectionProvider) as LaptopConnected).connection;

    phone.read(laptopConnectionProvider.notifier).ensureLinked();
    await Future<void>.delayed(const Duration(milliseconds: 400));

    final state = phone.read(laptopConnectionProvider) as LaptopConnected;
    expect(identical(state.connection, before), isTrue);
    expect(before.isOpen, isTrue);
  });

  test('a link the laptop closed comes back without any help', () async {
    final phone = await startPhone();

    hub().disconnect(_phoneHello.deviceId);

    await _eventually(
      () => phone.read(laptopConnectionProvider) is! LaptopConnected,
      what: 'the phone noticing',
    );
    await _eventually(
      () =>
          phone.read(laptopConnectionProvider) is LaptopConnected &&
          hub().isConnected(_phoneHello.deviceId),
      what: 'the phone reconnecting by itself',
    );
  });

  /// A laptop that only records what the phone tells it.
  Future<({DeviceEndpoint endpoint, List<String> frames})>
  startListeningLaptop() async {
    final listening = await HttpServer.bindSecure(
      InternetAddress.loopbackIPv4,
      0,
      testIdentity.createServerContext(),
    );
    addTearDown(() => listening.close(force: true));
    final frames = <String>[];
    listening.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      socket.listen((frame) {
        if (frame is String && !frame.contains('"ping"')) frames.add(frame);
      });
    });
    return (
      endpoint: DeviceEndpoint(
        host: listening.address,
        port: listening.port,
        certFingerprint: testIdentity.fingerprint,
      ),
      frames: frames,
    );
  }

  test('the phone tells the laptop when Sharely leaves the screen', () async {
    final laptop = await startListeningLaptop();
    final phone = await startPhoneLinkedTo(laptop.endpoint);
    final controller = phone.read(laptopConnectionProvider.notifier)
      ..reportOnScreen(isOnScreen: false);
    await _eventually(() => laptop.frames.isNotEmpty, what: 'off screen');

    controller.reportOnScreen(isOnScreen: true);
    await _eventually(() => laptop.frames.length == 2, what: 'on screen');

    expect(laptop.frames, [
      '{"type":"presence","onScreen":false}',
      '{"type":"presence","onScreen":true}',
    ]);
  });

  test('a link lost while off screen comes back', () async {
    final laptop = await startListeningLaptop();
    final phone = await startPhoneLinkedTo(laptop.endpoint);
    final first =
        (phone.read(laptopConnectionProvider) as LaptopConnected).connection;
    phone
        .read(laptopConnectionProvider.notifier)
        .reportOnScreen(isOnScreen: false);
    await _eventually(() => laptop.frames.isNotEmpty, what: 'off screen');

    // The link breaks while the phone is off screen; the next one goes
    // to the real laptop, which must hear it at once.
    await first.close();
    await _eventually(
      () => hub().isConnected(_phoneHello.deviceId),
      what: 'the new link',
    );

    // The laptop sees the new link a moment before the phone adopts it.
    await _eventually(
      () => phone.read(laptopConnectionProvider) is LaptopConnected,
      what: 'the phone showing connected',
    );
  });
}
