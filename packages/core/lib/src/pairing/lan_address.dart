import 'dart:io';

import 'package:sharely_core/src/protocol/protocol_exception.dart';

/// True for private IPv4 ranges (10/8, 172.16/12, 192.168/16).
///
/// Pairing only ever targets these, so a forged QR code cannot point the
/// phone at a server on the internet.
bool isPrivateLanAddress(InternetAddress address) {
  if (address.type != InternetAddressType.IPv4) return false;
  final [first, second, ...] = address.rawAddress;
  return first == 10 ||
      (first == 172 && second >= 16 && second <= 31) ||
      (first == 192 && second == 168);
}

/// True for a caller on this network or this machine. The server answers
/// nobody else, even if a router forwards a port to it by mistake.
bool isLocalNetworkPeer(InternetAddress address) =>
    address.isLoopback || isPrivateLanAddress(address);

// Adapters that lead only to this machine's own containers and VMs, to a
// VPN, or to the mobile network. They hold private addresses, but no
// paired device is ever on them, so they are never served on or searched.
final _unreachableInterfaceName = RegExp(
  // "veth" pairs belong to containers; Windows "vEthernet" does not.
  '^(docker|br-|veth(?!ernet)|virbr|vmnet|vboxnet|'
  'tun|tap|tailscale|zt|wg|utun|ppp|'
  'rmnet|ccmni|pdp|clat|v4-|dummy)|'
  'wsl|default switch|vmnet|host-only',
  caseSensitive: false,
);

// A Hyper-V "external" switch carries the real network under a virtual
// name, so these stay usable, but only when nothing better exists.
final _virtualSwitchName = RegExp(
  'vethernet|virtual|vmware|hyper-v',
  caseSensitive: false,
);

/// True when no phone or laptop can be reached through [interfaceName].
bool isUnreachableInterfaceName(String interfaceName) =>
    _unreachableInterfaceName.hasMatch(interfaceName);

/// True when [interfaceName] belongs to a virtual adapter, not real Wi-Fi.
bool isVirtualInterfaceName(String interfaceName) =>
    isUnreachableInterfaceName(interfaceName) ||
    _virtualSwitchName.hasMatch(interfaceName);

/// This machine's addresses on networks a paired device can share, most
/// likely Wi-Fi address first. Empty means it is on no such network.
Future<List<InternetAddress>> findLanAddresses() async {
  final interfaces = await NetworkInterface.list(
    type: InternetAddressType.IPv4,
  );
  return rankLanAddresses([
    for (final interface in interfaces)
      for (final address in interface.addresses)
        (interfaceName: interface.name, address: address),
  ]);
}

/// Keeps the private addresses another device could reach, real adapters
/// first, then the home range.
List<InternetAddress> rankLanAddresses(
  List<({String interfaceName, InternetAddress address})> candidates,
) {
  // Home routers almost always use 192.168.x.x; prefer it over VPN ranges.
  int rank(({String interfaceName, InternetAddress address}) candidate) =>
      (isVirtualInterfaceName(candidate.interfaceName) ? 2 : 0) +
      (candidate.address.rawAddress.first == 192 ? 0 : 1);
  final usable = [
    for (final candidate in candidates)
      if (isPrivateLanAddress(candidate.address) &&
          !isUnreachableInterfaceName(candidate.interfaceName))
        candidate,
  ]..sort((a, b) => rank(a).compareTo(rank(b)));
  return [for (final candidate in usable) candidate.address];
}

/// Whether a server on [current] should move, given the addresses this
/// machine has [now], best first.
///
/// It moves when its address is gone, and also when a better one has
/// appeared: after Wi-Fi drops, the only address left can be a Docker or
/// VM adapter no phone can reach, and the server must not stay there once
/// Wi-Fi is back.
bool shouldServeElsewhere(
  InternetAddress? current,
  List<InternetAddress> now,
) => now.firstOrNull != current;

/// Sharely never serves on, or connects to, a privileged or invalid port.
bool isValidServicePort(int port) => port >= 1024 && port <= 65535;

/// An untrusted host that must be a private LAN address.
InternetAddress parsePrivateLanHost(String host) {
  final address = InternetAddress.tryParse(host);
  if (address == null || !isPrivateLanAddress(address)) {
    throw const ProtocolException('Host is not a private LAN address');
  }
  return address;
}

/// An untrusted port that must be one Sharely may use.
int parseServicePort(int port) {
  if (!isValidServicePort(port)) {
    throw const ProtocolException('Port is out of range');
  }
  return port;
}
