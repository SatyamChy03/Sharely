import 'dart:io';

import 'package:sharely_core/sharely_core.dart';
import 'package:test/test.dart';

import '../support/test_tls.dart';

const _laptopHello = HelloMessage(
  deviceId: 'laptop_0123456789ab',
  deviceName: 'Laptop',
  platform: DevicePlatform.linux,
);

void main() {
  test('finds a Sharely laptop and skips hosts that are not one', () async {
    final session = PairingSession();
    final sharely = await SharelyServer.start(
      address: InternetAddress.loopbackIPv4,
      preferredPort: 0,
      identity: testIdentity,
      pairingHandler: PairingRequestHandler(
        currentSession: () => session,
        localHello: _laptopHello,
        onPaired: (_) {},
      ),
    );
    addTearDown(sharely.stop);
    // Something else answering HTTP on the same port of another address.
    final impostor = await HttpServer.bind('127.0.0.2', sharely.port);
    addTearDown(impostor.close);
    impostor.listen((request) async {
      request.response.write('<html>router admin</html>');
      await request.response.close();
    });

    final found = await LaptopFinder(port: sharely.port).probe([
      InternetAddress('127.0.0.1'),
      InternetAddress('127.0.0.2'),
      InternetAddress('127.0.0.3'),
    ]);

    expect(found.single.hello.deviceId, _laptopHello.deviceId);
    expect(found.single.endpoint.port, sharely.port);
  });

  test('a found laptop pairs with the typed six-digit code', () async {
    final session = PairingSession();
    final server = await SharelyServer.start(
      address: InternetAddress.loopbackIPv4,
      preferredPort: 0,
      identity: testIdentity,
      pairingHandler: PairingRequestHandler(
        currentSession: () => session,
        localHello: _laptopHello,
        onPaired: (_) {},
      ),
    );
    addTearDown(server.stop);
    final laptop = (await LaptopFinder(
      port: server.port,
    ).probe([InternetAddress.loopbackIPv4])).single;

    final paired = await const PairingClient().pair(
      invite: PairingInvite(
        host: laptop.endpoint.host,
        port: laptop.endpoint.port,
        token: session.code,
        certFingerprint: laptop.endpoint.certFingerprint,
        deviceId: laptop.hello.deviceId,
        deviceName: laptop.hello.deviceName,
      ),
      localHello: const HelloMessage(
        deviceId: 'phone_0123456789abc',
        deviceName: 'Phone',
        platform: DevicePlatform.android,
      ),
    );

    expect(paired.deviceId, _laptopHello.deviceId);
  });

  test('neighbours cover the /24 except this device', () {
    final hosts = neighboursOf(InternetAddress('192.168.1.24'));

    expect(hosts, hasLength(253));
    expect(hosts.map((host) => host.address), isNot(contains('192.168.1.24')));
    expect(hosts.first.address, '192.168.1.1');
  });
}
