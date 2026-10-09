import 'dart:io';

import 'package:sharely_core/sharely_core.dart';
import 'package:test/test.dart';

const _token = 'tok_0123456789abcdef';
const _laptopId = 'laptop_0123456789ab';
const _fingerprint = 'GC7sBY-wnhn-hzeInIlX3XANDNAagCm_dWCmPH5UdVQ';

String _invite({
  String host = '192.168.1.24',
  String port = '53891',
  String fingerprint = _fingerprint,
  String extra = '',
}) {
  return 'sharely://pair?v=2&h=$host&p=$port&t=$_token&f=$fingerprint&id=$_laptopId'
      "&n=Satyam's%20Laptop$extra";
}

void main() {
  test('round trips through the QR text', () {
    final invite = PairingInvite(
      host: InternetAddress('10.0.0.7'),
      port: 53891,
      token: _token,
      certFingerprint: _fingerprint,
      deviceId: _laptopId,
      deviceName: "Satyam's Laptop",
    );
    final parsed = PairingInvite.parse(invite.toUriString());
    expect(parsed.host.address, '10.0.0.7');
    expect(parsed.port, 53891);
    expect(parsed.token, _token);
    expect(parsed.certFingerprint, _fingerprint);
    expect(parsed.deviceName, "Satyam's Laptop");
  });

  group('rejects', () {
    final invalidInvites = {
      'a public internet address': _invite(host: '8.8.8.8'),
      'loopback': _invite(host: '127.0.0.1'),
      'a hostname instead of an IP': _invite(host: 'evil.example.com'),
      'a privileged port': _invite(port: '80'),
      'a non-numeric port': _invite(port: 'http'),
      'an extra parameter': _invite(extra: '&admin=1'),
      'a fingerprint of the wrong length': _invite(fingerprint: 'abc'),
      'a fingerprint with other characters': _invite(
        fingerprint: '${'A' * 42}!',
      ),
      'the old format without a certificate':
          'sharely://pair?v=1&h=192.168.1.24&p=53891&t=$_token'
          '&id=$_laptopId&n=Laptop',
      'a web URL': 'https://example.com/pair',
      'plain text': 'hello',
      'an oversized code': _invite(extra: '&x=${'a' * 600}'),
    };
    for (final MapEntry(key: description, value: text)
        in invalidInvites.entries) {
      test(description, () {
        expect(
          () => PairingInvite.parse(text),
          throwsA(isA<ProtocolException>()),
        );
      });
    }
  });

  test('only private IPv4 ranges count as LAN addresses', () {
    bool isLan(String ip) => isPrivateLanAddress(InternetAddress(ip));
    expect(isLan('192.168.0.10'), isTrue);
    expect(isLan('172.16.5.4'), isTrue);
    expect(isLan('172.31.255.1'), isTrue);
    expect(isLan('10.20.30.40'), isTrue);
    expect(isLan('172.32.0.1'), isFalse);
    expect(isLan('8.8.8.8'), isFalse);
    expect(isLan('127.0.0.1'), isFalse);
    expect(isLan('::1'), isFalse);
  });
}
