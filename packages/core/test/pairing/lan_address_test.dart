import 'dart:io';

import 'package:sharely_core/sharely_core.dart';
import 'package:test/test.dart';

void main() {
  test('Docker and VM adapters are never offered, even on their own', () {
    final onlyVirtual = rankLanAddresses([
      (interfaceName: 'docker0', address: InternetAddress('172.17.0.1')),
      (interfaceName: 'br-4f2a9c1d', address: InternetAddress('172.18.0.1')),
      (interfaceName: 'veth9a1b2c3', address: InternetAddress('172.19.0.1')),
      (interfaceName: 'virbr0', address: InternetAddress('192.168.122.1')),
      (interfaceName: 'vboxnet0', address: InternetAddress('192.168.56.1')),
    ]);

    expect(onlyVirtual, isEmpty);
  });

  test('Wi-Fi is the only address offered beside Docker', () {
    final ranked = rankLanAddresses([
      (interfaceName: 'docker0', address: InternetAddress('172.17.0.1')),
      (interfaceName: 'wlp8s0', address: InternetAddress('192.168.1.18')),
    ]);

    expect(ranked.map((address) => address.address), ['192.168.1.18']);
  });

  test('VPN and mobile-data adapters are never offered', () {
    final ranked = rankLanAddresses([
      (interfaceName: 'tun0', address: InternetAddress('10.8.0.2')),
      (interfaceName: 'wg0', address: InternetAddress('10.9.0.2')),
      (interfaceName: 'rmnet_data2', address: InternetAddress('10.44.3.9')),
      (interfaceName: 'wlan0', address: InternetAddress('192.168.43.1')),
    ]);

    expect(ranked.map((address) => address.address), ['192.168.43.1']);
  });

  test('Windows adapters that reach only this PC are never offered', () {
    final names = [
      'vEthernet (WSL)',
      'vEthernet (WSL (Hyper-V firewall))',
      'vEthernet (Default Switch)',
      'VMware Network Adapter VMnet8',
      'VirtualBox Host-Only Network',
    ];

    for (final name in names) {
      expect(isUnreachableInterfaceName(name), isTrue, reason: name);
    }
  });

  test('a Hyper-V external switch is kept, behind real adapters', () {
    final ranked = rankLanAddresses([
      (
        interfaceName: 'vEthernet (External Switch)',
        address: InternetAddress('192.168.1.40'),
      ),
      (interfaceName: 'Wi-Fi', address: InternetAddress('192.168.1.18')),
    ]);

    expect(ranked.map((address) => address.address), [
      '192.168.1.18',
      '192.168.1.40',
    ]);
    expect(
      rankLanAddresses([
        (
          interfaceName: 'vEthernet (External Switch)',
          address: InternetAddress('192.168.1.40'),
        ),
      ]),
      hasLength(1),
    );
  });

  test('ordinary adapter names are not mistaken for virtual ones', () {
    final names = [
      'Wi-Fi',
      'Ethernet',
      'wlan0',
      'wlp8s0',
      'eth0',
      'enp3s0',
      'en0',
      'br0',
      'ap0',
      'swlan0',
      'Wi-Fi 2',
      'vEthernet (External Switch)',
    ];

    for (final name in names) {
      expect(isUnreachableInterfaceName(name), isFalse, reason: name);
    }
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

  group('a running server', () {
    final wifi = InternetAddress('192.168.1.18');
    final docker = InternetAddress('172.17.0.1');

    test('stays while its address is still the best one', () {
      expect(shouldServeElsewhere(wifi, [wifi, docker]), isFalse);
    });

    test('moves when its address is gone', () {
      expect(shouldServeElsewhere(wifi, [docker]), isTrue);
    });

    test('leaves a Docker address as soon as Wi-Fi is back', () {
      expect(shouldServeElsewhere(docker, [wifi, docker]), isTrue);
    });

    test('starts once a network appears, and waits while there is none', () {
      expect(shouldServeElsewhere(null, [wifi]), isTrue);
      expect(shouldServeElsewhere(null, const []), isFalse);
    });
  });
}
