import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sharely/app/storage/trust_store_provider.dart';
import 'package:sharely/features/home/devices_tab.dart';
import 'package:sharely/features/pairing/state/local_identity.dart';
import 'package:sharely/features/pairing/state/paired_devices.dart';
import 'package:sharely/features/transfer/state/laptop_connection_controller.dart';
import 'package:sharely/features/transfer/state/laptop_connection_state.dart';
import 'package:sharely/features/transfer/state/transfer_in_flight.dart';
import 'package:sharely_core/sharely_core.dart';

import '../../support/test_tls.dart';

const _authToken = 'auth_0123456789abcdef0123456789abcdef';
const _phoneHello = HelloMessage(
  deviceId: 'phone_0123456789abc',
  deviceName: 'Phone',
  platform: DevicePlatform.android,
);
final PairedDevice _phoneRecord = PairedDevice.fromHello(
  _phoneHello,
  authToken: _authToken,
  pairedAt: DateTime.utc(2026, 10, 5),
);

/// A real laptop server on loopback that knows the phone.
class _Laptop {
  new _(this.record, this.hub, this._server, this._receiver, this._sender);

  final PairedDevice record;
  final ControlHub hub;
  final SharelyServer _server;
  final TransferReceiver _receiver;
  final TransferSender _sender;

  bool get hasPhone => hub.isConnected(_phoneHello.deviceId);

  static Future<_Laptop> start(String name) async {
    final hello = HelloMessage(
      deviceId: '${name.toLowerCase()}_0123456789abc',
      deviceName: name,
      platform: DevicePlatform.windows,
    );
    final receiver = TransferReceiver(
      saveDirectory: () async => Directory.systemTemp,
    );
    final sender = TransferSender(hub: receiver.hub);
    final server = await SharelyServer.start(
      address: InternetAddress.loopbackIPv4,
      preferredPort: 0,
      identity: testIdentity,
      pairingHandler: PairingRequestHandler(
        currentSession: () => null,
        localHello: hello,
        onPaired: (_) {},
      ),
      transfers: (
        receiver: receiver,
        sender: sender,
        findPairedDevice: (deviceId) =>
            deviceId == _phoneRecord.deviceId ? _phoneRecord : null,
      ),
    );
    final record = PairedDevice.fromHello(
      hello,
      authToken: _authToken,
      pairedAt: DateTime.utc(2026, 10, 5),
      endpoint: DeviceEndpoint(
        host: server.address,
        port: server.port,
        certFingerprint: testIdentity.fingerprint,
      ),
    );
    final laptop = _Laptop._(record, receiver.hub, server, receiver, sender);
    addTearDown(laptop._stop);
    return laptop;
  }

  Future<void> _stop() async {
    await _sender.close();
    await _receiver.close();
    await _server.stop();
  }
}

Future<void> _eventually(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) fail('Condition never became true');
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

class _FixedPairedDevices extends PairedDevicesNotifier {
  new(this._devices);

  final List<PairedDevice> _devices;

  @override
  Future<List<PairedDevice>> build() async => _devices;
}

class _FixedConnection extends LaptopConnectionController {
  new(this._state);

  final LaptopConnectionState _state;
  final calls = <String>[];

  @override
  LaptopConnectionState build() => _state;

  @override
  void connect() => calls.add('connect');

  @override
  void disconnect() => calls.add('disconnect');
}

PairedDevice _named(String name) => PairedDevice(
  deviceId: '${name.toLowerCase()}_0123456789abc',
  deviceName: name,
  platform: DevicePlatform.windows,
  authToken: _authToken,
  pairedAt: DateTime.utc(2026, 10, 5),
);

void main() {
  group('with two laptops paired', () {
    late _Laptop office;
    late _Laptop home;
    late ProviderContainer phone;

    String? connectedLaptop() {
      final connection = phone.read(laptopConnectionProvider);
      return connection is LaptopConnected
          ? connection.laptop.deviceName
          : null;
    }

    Iterable<String>? pairedNames() =>
        phone.read(pairedDevicesProvider).value?.map((d) => d.deviceName);

    setUp(() async {
      // The widget tests below make Flutter stub out HTTP for this file.
      HttpOverrides.global = null;
      office = await _Laptop.start('Office');
      home = await _Laptop.start('Home');
      phone = ProviderContainer(
        overrides: [
          trustStoreProvider.overrideWithValue(TrustStore(MemorySecretStore())),
          localHelloProvider.overrideWith((ref) async => _phoneHello),
        ],
      );
      addTearDown(phone.dispose);
      final devices = phone.read(pairedDevicesProvider.notifier);
      await devices.trust(office.record);
      await devices.trust(home.record);
      phone.listen(laptopConnectionProvider, (_, _) {});
      await _eventually(() => connectedLaptop() == 'Home');
    });

    test('the phone uses the laptop paired last and keeps the other', () async {
      await _eventually(() => home.hasPhone);
      expect(office.hasPhone, isFalse);
      expect(pairedNames(), ['Office', 'Home']);
    });

    test('choosing the other laptop moves the connection to it', () async {
      await phone
          .read(pairedDevicesProvider.notifier)
          .makeActive(office.record.deviceId);

      await _eventually(() => connectedLaptop() == 'Office');
      await _eventually(() => office.hasPhone && !home.hasPhone);
      expect(pairedNames(), ['Home', 'Office']);
    });

    test('disconnect closes the link, keeps the pairing, and connect '
        'restores it', () async {
      await _eventually(() => home.hasPhone);
      final controller = phone.read(laptopConnectionProvider.notifier)
        ..disconnect();

      expect(phone.read(laptopConnectionProvider), isA<LaptopDisconnected>());
      await _eventually(() => !home.hasPhone);
      expect(pairedNames(), hasLength(2));
      // Stays off: no retry brings it back behind the user's back.
      controller.retryNow();
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(home.hasPhone, isFalse);

      controller.connect();

      await _eventually(() => connectedLaptop() == 'Home' && home.hasPhone);
    });

    test('choosing another laptop while disconnected connects to it', () async {
      phone.read(laptopConnectionProvider.notifier).disconnect();

      await phone
          .read(pairedDevicesProvider.notifier)
          .makeActive(office.record.deviceId);

      await _eventually(() => connectedLaptop() == 'Office');
    });

    test('forgetting the laptop in use falls back to the other one', () async {
      await phone
          .read(pairedDevicesProvider.notifier)
          .forget(home.record.deviceId);

      await _eventually(() => connectedLaptop() == 'Office');
      await _eventually(() => !home.hasPhone);
    });
  });

  group('the Devices tab', () {
    Future<_FixedConnection> pump(
      WidgetTester tester, {
      bool isBusy = false,
    }) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final connection = _FixedConnection(LaptopUnreachable(_named('Home')));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            pairedDevicesProvider.overrideWith(
              () => _FixedPairedDevices([_named('Office'), _named('Home')]),
            ),
            laptopConnectionProvider.overrideWith(() => connection),
            isTransferInFlightProvider.overrideWithValue(isBusy),
          ],
          child: const MaterialApp(home: Scaffold(body: DevicesTabView())),
        ),
      );
      await tester.pump();
      return connection;
    }

    testWidgets('lists every laptop with connect, remove and add device', (
      tester,
    ) async {
      final connection = await pump(tester);

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Office'), findsOneWidget);
      expect(find.text('Connect'), findsNWidgets(2));
      expect(find.text('Remove'), findsNWidgets(2));
      expect(find.text('Add device'), findsOneWidget);
      // The laptop in use comes first.
      expect(
        tester.getTopLeft(find.text('Home')).dy,
        lessThan(tester.getTopLeft(find.text('Office')).dy),
      );

      await tester.tap(find.text('Connect').first);
      await tester.pump();
      expect(connection.calls, ['connect']);
    });

    testWidgets('removing asks first and keeps the laptop on "Keep"', (
      tester,
    ) async {
      await pump(tester);

      await tester.tap(find.text('Remove').first);
      await tester.pumpAndSettle();
      expect(find.text('Remove Home?'), findsOneWidget);

      await tester.tap(find.text('Keep'));
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('nothing can be changed while files are moving', (
      tester,
    ) async {
      final connection = await pump(tester, isBusy: true);

      expect(
        find.text('Finish or cancel the transfer to change laptops.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Connect').first);
      await tester.tap(find.text('Remove').first);
      await tester.pumpAndSettle();
      expect(connection.calls, isEmpty);
      expect(find.text('Remove Home?'), findsNothing);
    });
  });
}
