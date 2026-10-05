import 'package:sharely_core/sharely_core.dart';

sealed class LaptopPairingState {
  const new();
}

/// Showing a QR code and code, waiting for a phone.
final class LaptopWaitingForPhone extends LaptopPairingState {
  const new({
    required this.invite,
    required this.code,
    required this.expiresAt,
  });

  final PairingInvite invite;
  final String code;
  final DateTime expiresAt;
}

final class LaptopPairedWithPhone extends LaptopPairingState {
  const new(this.phone);

  final PairedDevice phone;
}

/// No private Wi-Fi/LAN address, so a phone could never reach us.
final class LaptopNotOnNetwork extends LaptopPairingState {
  const new();
}
