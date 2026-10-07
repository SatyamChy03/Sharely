import 'dart:convert';
import 'dart:io';

import 'package:sharely_core/sharely_core.dart';
import 'package:sharely_core/src/discovery/locate_query.dart';
import 'package:sharely_core/src/discovery/locate_reply.dart';
import 'package:test/test.dart';

const _laptopId = 'laptop_0123456789ab';
const _phoneId = 'phone_0123456789abc';
const _authToken = 'auth_0123456789abcdef';
const _fastLocator = Duration(milliseconds: 150);

final _serverEndpoint = DeviceEndpoint.parse(host: '192.168.1.42', port: 5500);

PairedDevice _device(String deviceId, {String authToken = _authToken}) {
  return PairedDevice(
    deviceId: deviceId,
    deviceName: 'Device',
    platform: DevicePlatform.windows,
    authToken: authToken,
    pairedAt: DateTime.utc(2026, 10, 7),
  );
}

Future<DiscoveryResponder> _startResponder({
  String pairedPhoneToken = _authToken,
}) async {
  final responder = await DiscoveryResponder.start(
    localDeviceId: _laptopId,
    serverEndpoint: _serverEndpoint,
    findPairedDevice: (deviceId) => deviceId == _phoneId
        ? _device(_phoneId, authToken: pairedPhoneToken)
        : null,
    bindAddress: InternetAddress.loopbackIPv4,
    port: 0,
  );
  addTearDown(responder.stop);
  return responder;
}

Future<DeviceEndpoint?> _locate(int port, {String localDeviceId = _phoneId}) {
  return LaptopLocator(
    port: port,
    rounds: 2,
    roundTimeout: _fastLocator,
  ).locate(
    laptop: _device(_laptopId),
    localDeviceId: localDeviceId,
    targets: [InternetAddress.loopbackIPv4],
  );
}

/// A stand-in laptop that answers every query with [buildReply]'s bytes.
Future<int> _startImpostor(
  List<int> Function(LocateQuery query) buildReply,
) async {
  final socket = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
  addTearDown(socket.close);
  socket.listen((event) {
    final datagram = socket.receive();
    if (datagram == null) return;
    final query = LocateQuery.decode(datagram.data);
    socket.send(buildReply(query), datagram.address, datagram.port);
  });
  return socket.port;
}

void main() {
  test('a paired phone learns where the laptop serves now', () async {
    final responder = await _startResponder();

    expect(await _locate(responder.port), _serverEndpoint);
  });

  test('an unpaired device gets no answer', () async {
    final responder = await _startResponder();

    final found = await _locate(
      responder.port,
      localDeviceId: 'stranger_0123456789',
    );

    expect(found, isNull);
  });

  test('a laptop holding a different token is not believed', () async {
    final responder = await _startResponder(
      pairedPhoneToken: 'other_0123456789abcdef',
    );

    expect(await _locate(responder.port), isNull);
  });

  test('a reply signed for another address is rejected', () async {
    final port = await _startImpostor((query) {
      final genuine = LocateReply.signed(
        nonce: query.nonce,
        deviceId: _laptopId,
        endpoint: _serverEndpoint,
        authToken: _authToken,
      );
      return LocateReply(
        deviceId: _laptopId,
        endpoint: DeviceEndpoint.parse(host: '192.168.1.66', port: 5500),
        proof: genuine.proof,
      ).encode();
    });

    expect(await _locate(port), isNull);
  });

  test('a replayed reply for an older question is rejected', () async {
    final port = await _startImpostor(
      (query) => LocateReply.signed(
        nonce: 'stale_nonce_0123456789',
        deviceId: _laptopId,
        endpoint: _serverEndpoint,
        authToken: _authToken,
      ).encode(),
    );

    expect(await _locate(port), isNull);
  });

  test('garbage and oversized replies are ignored', () async {
    final port = await _startImpostor((_) => List.filled(600, 0x7b));

    expect(await _locate(port), isNull);
  });

  test('a reply pointing outside the local network is rejected', () {
    final datagram = utf8.encode(
      jsonEncode({
        'type': 'located',
        'v': 1,
        'deviceId': _laptopId,
        'host': '8.8.8.8',
        'port': 5500,
        'proof': 'a' * 64,
      }),
    );

    expect(
      () => LocateReply.decode(datagram),
      throwsA(isA<ProtocolException>()),
    );
  });

  test('a query with unknown fields or a bad id is rejected', () {
    List<int> query(Map<String, Object> extra) => utf8.encode(
      jsonEncode({'type': 'locate', 'v': 1, 'nonce': 'n' * 22, ...extra}),
    );

    expect(
      () => LocateQuery.decode(query({'from': _phoneId, 'extra': true})),
      throwsA(isA<ProtocolException>()),
    );
    expect(
      () => LocateQuery.decode(query({'from': '../etc'})),
      throwsA(isA<ProtocolException>()),
    );
  });
}
