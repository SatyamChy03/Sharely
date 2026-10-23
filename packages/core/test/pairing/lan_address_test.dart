import 'dart:io';

import 'package:sharely_core/sharely_core.dart';
import 'package:test/test.dart';

void main() {
  test('Wi-Fi is preferred over Docker and VM adapters', () {
    final ranked = rankLanAddresses([
      (interfaceName: 'docker0', address: InternetAddress('172.17.0.1')),
      (interfaceName: 'virbr0', address: InternetAddress('192.168.122.1')),
      (interfaceName: 'wlp8s0', address: InternetAddress('172.25.13.173')),
    ]);

    expect(ranked.first.address, '172.25.13.173');
  });

  test('public and loopback addresses are never offered', () {
    final ranked = rankLanAddresses([
      (interfaceName: 'lo', address: InternetAddress.loopbackIPv4),
      (interfaceName: 'eth0', address: InternetAddress('8.8.8.8')),
      (interfaceName: 'wlan0', address: InternetAddress('192.168.1.5')),
    ]);

    expect(ranked.map((address) => address.address), ['192.168.1.5']);
  });

  test('Windows virtual switch names count as virtual', () {
    expect(isVirtualInterfaceName('vEthernet (WSL)'), isTrue);
    expect(isVirtualInterfaceName('Wi-Fi'), isFalse);
  });

  test('the server answers only this network and this machine', () {
    bool isLocal(String ip) => isLocalNetworkPeer(InternetAddress(ip));
    expect(isLocal('192.168.1.20'), isTrue);
    expect(isLocal('10.0.0.5'), isTrue);
    expect(isLocal('127.0.0.1'), isTrue);
    expect(isLocal('8.8.8.8'), isFalse);
    expect(isLocal('172.32.0.1'), isFalse);
    expect(isLocal('2001:db8::1'), isFalse);
  });
}
