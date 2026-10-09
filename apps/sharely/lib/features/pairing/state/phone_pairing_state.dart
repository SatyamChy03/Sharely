import 'package:sharely_core/sharely_core.dart';

/// Why pairing failed, phrased for one plain-language fix each.
enum PhonePairingIssue {
  notSharelyCode,
  unreachable,
  expiredCode,
  mismatch,
  noLaptopFound,
  wrongCode,
}

sealed class PhonePairingState {
  const new();
}

final class PhoneReadyToScan extends PhonePairingState {
  const new();
}

/// Sweeping this Wi-Fi for a laptop to try a typed code on.
final class PhoneSearchingForLaptop extends PhonePairingState {
  const new();
}

/// Several laptops answered; the user picks theirs by name.
final class PhoneChoosingLaptop extends PhonePairingState {
  const new(this.laptops, this.code);

  final List<FoundLaptop> laptops;
  final String code;
}

final class PhoneConnecting extends PhonePairingState {
  const new(this.laptopName);

  final String laptopName;
}

final class PhonePaired extends PhonePairingState {
  const new(this.laptop);

  final PairedDevice laptop;
}

final class PhonePairingFailed extends PhonePairingState {
  const new(this.issue);

  final PhonePairingIssue issue;
}
