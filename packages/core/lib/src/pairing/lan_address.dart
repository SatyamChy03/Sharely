import 'dart:io';

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

// Docker, VM and VPN adapters also hold private addresses, but no phone
// can reach the laptop through them.
final _virtualInterfaceName = RegExp(
  '^(docker|br-|veth|virbr|vmnet|vboxnet|tun|tap|tailscale|zt|wg)|'
  'vethernet|virtual|vmware|hyper-v|wsl',
  caseSensitive: false,
);

/// True when [interfaceName] belongs to a virtual adapter, not real Wi-Fi.
bool isVirtualInterfaceName(String interfaceName) =>
    _virtualInterfaceName.hasMatch(interfaceName);

/// Private IPv4 addresses of this machine, most likely Wi-Fi address first.
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

/// Orders private addresses: real adapters first, then the home range.
List<InternetAddress> rankLanAddresses(
  List<({String interfaceName, InternetAddress address})> candidates,
) {
  // Home routers almost always use 192.168.x.x; prefer it over VPN ranges.
  int rank(({String interfaceName, InternetAddress address}) candidate) =>
      (isVirtualInterfaceName(candidate.interfaceName) ? 2 : 0) +
      (candidate.address.rawAddress.first == 192 ? 0 : 1);
  final usable = [
    for (final candidate in candidates)
      if (isPrivateLanAddress(candidate.address)) candidate,
  ]..sort((a, b) => rank(a).compareTo(rank(b)));
  return [for (final candidate in usable) candidate.address];
}

/// Sharely never serves on, or connects to, a privileged or invalid port.
bool isValidServicePort(int port) => port >= 1024 && port <= 65535;
