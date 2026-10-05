import 'dart:convert';
import 'dart:io';

import 'package:sharely_core/sharely_core.dart';
import 'package:test/test.dart';

const _laptopHello = HelloMessage(
  deviceId: 'laptop_0123456789ab',
  deviceName: "Satyam's Laptop",
  platform: DevicePlatform.windows,
);
const _phoneHello = HelloMessage(
  deviceId: 'phone_0123456789abc',
  deviceName: "Satyam's Phone",
  platform: DevicePlatform.android,
);

/// A laptop with a live server and pairing session, on loopback for tests.
class _TestLaptop {
  final session = PairingSession();
  final paired = <PairedDevice>[];
  late final SharelyServer server;

  Future<void> start() async {
    server = await SharelyServer.start(
      address: InternetAddress.loopbackIPv4,
      preferredPort: 0,
      pairingHandler: PairingRequestHandler(
        currentSession: () => session,
        localHello: _laptopHello,
        onPaired: paired.add,
      ),
    );
  }

  // Built directly because parse() rightly refuses loopback addresses.
  PairingInvite invite({String? token, String? deviceId}) => PairingInvite(
    host: server.address,
    port: server.port,
    token: token ?? session.token,
    deviceId: deviceId ?? _laptopHello.deviceId,
    deviceName: _laptopHello.deviceName,
  );
}

Future<PairedDevice> _pair(PairingInvite invite) {
  return const PairingClient().pair(invite: invite, localHello: _phoneHello);
}

Matcher _failsWith(PairingFailure failure) => throwsA(
  isA<PairingException>().having((e) => e.failure, 'failure', failure),
);

void main() {
  late _TestLaptop laptop;

  setUp(() async {
    laptop = _TestLaptop();
    await laptop.start();
  });

  tearDown(() => laptop.server.stop());

  group('successful pairing', () => _successTests(() => laptop));
  group('refused pairing', () => _refusalTests(() => laptop));
}

void _successTests(_TestLaptop Function() laptopUnderTest) {
  test('both sides end up trusting each other with one token', () async {
    final laptop = laptopUnderTest();
    final trustedLaptop = await _pair(laptop.invite());

    expect(trustedLaptop.deviceId, _laptopHello.deviceId);
    expect(trustedLaptop.platform, DevicePlatform.windows);
    expect(laptop.paired.single.deviceId, _phoneHello.deviceId);
    expect(laptop.paired.single.authToken, trustedLaptop.authToken);
    expect(trustedLaptop.toString(), isNot(contains(trustedLaptop.authToken)));
  });
}

void _refusalTests(_TestLaptop Function() laptopUnderTest) {
  test('a replayed QR token is rejected', () async {
    final laptop = laptopUnderTest();
    await _pair(laptop.invite());
    await expectLater(
      _pair(laptop.invite()),
      _failsWith(PairingFailure.rejected),
    );
  });

  test('a wrong token is rejected and pairs nothing', () async {
    final laptop = laptopUnderTest();
    final guess = laptop.invite(token: 'guess_0123456789abcd');
    await expectLater(_pair(guess), _failsWith(PairingFailure.rejected));
    expect(laptop.paired, isEmpty);
  });

  test('a different laptop answering is not trusted', () async {
    final laptop = laptopUnderTest();
    final impostor = laptop.invite(deviceId: 'other_0123456789abcd');
    await expectLater(
      _pair(impostor),
      _failsWith(PairingFailure.invalidResponse),
    );
  });

  test('an oversized request body is refused', () async {
    final laptop = laptopUnderTest();
    final client = HttpClient();
    addTearDown(client.close);
    final request =
        await client.post(
            laptop.server.address.address,
            laptop.server.port,
            '/v1/pair',
          )
          ..write(jsonEncode({'secret': 'x' * 8000}));
    final response = await request.close();
    expect(response.statusCode, HttpStatus.badRequest);
    expect(laptop.session.isActive, isTrue);
  });

  test('no server at the address reports unreachable', () async {
    final laptop = laptopUnderTest();
    final invite = laptop.invite();
    await laptop.server.stop();
    await expectLater(_pair(invite), _failsWith(PairingFailure.unreachable));
  });
}
