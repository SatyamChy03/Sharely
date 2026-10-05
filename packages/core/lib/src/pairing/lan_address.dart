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

/// Private IPv4 addresses of this machine, most likely Wi-Fi address first.
Future<List<InternetAddress>> findLanAddresses() async {
  final interfaces = await NetworkInterface.list(
    type: InternetAddressType.IPv4,
  );
  // Home routers almost always use 192.168.x.x; prefer it over VPN ranges.
  int homeRangeRank(InternetAddress address) =>
      address.rawAddress.first == 192 ? 0 : 1;
  return [
    for (final interface in interfaces)
      for (final address in interface.addresses)
        if (isPrivateLanAddress(address)) address,
  ]..sort((a, b) => homeRangeRank(a).compareTo(homeRangeRank(b)));
}

/// Sharely never serves on, or connects to, a privileged or invalid port.
bool isValidServicePort(int port) => port >= 1024 && port <= 65535;
