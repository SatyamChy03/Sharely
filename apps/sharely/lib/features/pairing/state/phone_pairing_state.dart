import 'package:sharely_core/sharely_core.dart';

/// Why pairing failed, phrased for one plain-language fix each.
enum PhonePairingIssue { notSharelyCode, unreachable, expiredCode, mismatch }

sealed class PhonePairingState {
  const new();
}

final class PhoneReadyToScan extends PhonePairingState {
  const new();
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
