import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:sharely_core/sharely_core.dart';
import 'package:test/test.dart';

import '../support/test_tls.dart';
import '../transfer/transfer_harness.dart';

const _laptopHello = HelloMessage(
  deviceId: 'laptop_0123456789ab',
  deviceName: 'Laptop',
  platform: DevicePlatform.linux,
);
const _phoneHello = HelloMessage(
  deviceId: 'phone_0123456789abc',
  deviceName: 'Phone',
  platform: DevicePlatform.android,
);

/// Another machine answering TLS at an address the phone trusts, with a
/// certificate of its own. Records every request that gets through.
Future<({DeviceEndpoint claimed, List<HttpRequest> requests})>
_startImpostor() async {
  final server = await HttpServer.bindSecure(
    InternetAddress.loopbackIPv4,
    0,
    TlsIdentity.generate().createServerContext(),
  );
  addTearDown(() => server.close(force: true));
  final requests = <HttpRequest>[];
  server.listen((request) async {
    requests.add(request);
    request.response.write(
      jsonEncode({
        'authToken': 'stolen_0123456789abcdef',
        'hello': _laptopHello.toJson(),
      }),
    );
    await request.response.close();
  });
  final claimed = DeviceEndpoint(
    host: server.address,
    port: server.port,
    certFingerprint: testIdentity.fingerprint,
  );
  return (claimed: claimed, requests: requests);
}

void main() {
  test('the server does not speak unencrypted HTTP', () async {
    final harness = await TransferHarness.start();
    final client = HttpClient();
    addTearDown(() => client.close(force: true));

    Future<void> askInTheClear() async {
      final request = await client.get(
        harness.server.address.address,
        harness.server.port,
        '/v1/hello',
      );
      await (await request.close()).drain<void>();
    }

    await expectLater(askInTheClear(), throwsA(isA<IOException>()));
  });

  test('a client trusting the usual authorities still refuses it', () async {
    final harness = await TransferHarness.start();
    final client = HttpClient();
    addTearDown(() => client.close(force: true));

    await expectLater(
      client.getUrl(harness.endpoint.httpsUri('/v1/hello')),
      throwsA(isA<HandshakeException>()),
    );
  });

  test(
    'pairing sends no secret to a server with another certificate',
    () async {
      final impostor = await _startImpostor();
      final invite = PairingInvite(
        host: impostor.claimed.host,
        port: impostor.claimed.port,
        token: 'tok_0123456789abcdef',
        certFingerprint: testIdentity.fingerprint,
        deviceId: _laptopHello.deviceId,
        deviceName: _laptopHello.deviceName,
      );

      await expectLater(
        const PairingClient().pair(invite: invite, localHello: _phoneHello),
        throwsA(
          isA<PairingException>().having(
            (error) => error.failure,
            'failure',
            PairingFailure.invalidResponse,
          ),
        ),
      );
      expect(impostor.requests, isEmpty);
    },
  );

  test('a wrong fingerprint leaves the pairing code unspent', () async {
    final session = PairingSession();
    final server = await SharelyServer.start(
      address: InternetAddress.loopbackIPv4,
      preferredPort: 0,
      identity: testIdentity,
      pairingHandler: PairingRequestHandler(
        currentSession: () => session,
        localHello: _laptopHello,
        onPaired: (_) => fail('Nothing may pair'),
      ),
    );
    addTearDown(server.stop);
    final invite = PairingInvite(
      host: server.address,
      port: server.port,
      token: session.token,
      certFingerprint: unknownFingerprint,
      deviceId: _laptopHello.deviceId,
      deviceName: _laptopHello.deviceName,
    );

    await expectLater(
      const PairingClient().pair(invite: invite, localHello: _phoneHello),
      throwsA(isA<PairingException>()),
    );
    expect(session.isActive, isTrue);
    expect(session.redeem(session.token), isTrue);
  });

  test('the control channel never reaches an impostor', () async {
    final impostor = await _startImpostor();

    await expectLater(
      ControlConnection.connect(
        impostor.claimed,
        authHeaders: buildAuthHeaders(
          localDeviceId: phone.deviceId,
          authToken: phone.authToken,
        ),
      ),
      throwsA(isA<TransferException>()),
    );
    expect(impostor.requests, isEmpty);
  });

  test('an upload never reaches an impostor', () async {
    final harness = await TransferHarness.start();
    harness.acceptEveryOffer();
    final impostor = await _startImpostor();
    final connection = await harness.connect();
    final file = await harness.writeFile('secret.txt', utf8.encode('private'));

    final transfer = OutgoingTransfer.start(
      files: [file],
      connection: connection,
      // The offer goes to the real laptop; the bytes are aimed elsewhere.
      endpoint: impostor.claimed,
      authHeaders: harness.authHeadersFor(phone),
      resumeWindow: const Duration(milliseconds: 600),
      retryDelay: const Duration(milliseconds: 100),
    );

    await expectLater(transfer.done, throwsA(isA<TransferException>()));
    expect(impostor.requests, isEmpty);
    expect(harness.savedFiles(), isEmpty);
  });

  test('looking for laptops reports the certificate each one showed', () async {
    final harness = await TransferHarness.start();

    final found = await LaptopFinder(port: harness.server.port)
        .probe([InternetAddress.loopbackIPv4]);

    expect(found.single.endpoint.certFingerprint, testIdentity.fingerprint);
  });
}
