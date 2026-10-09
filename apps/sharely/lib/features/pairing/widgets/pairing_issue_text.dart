import 'package:sharely/features/pairing/state/phone_pairing_state.dart';

/// What went wrong while pairing, and the one thing to try next.
({String title, String fix}) describePairingIssue(PhonePairingIssue issue) {
  return switch (issue) {
    PhonePairingIssue.notSharelyCode => (
      title: "That isn't a Sharely code",
      fix: 'Scan the code shown in Sharely on your laptop.',
    ),
    PhonePairingIssue.unreachable => (
      title: "Can't reach your laptop",
      fix:
          'Join the same Wi-Fi, and allow Sharely through the '
          "laptop's firewall.",
    ),
    PhonePairingIssue.expiredCode => (
      title: 'This code expired or was already used',
      fix: 'Show a new code on your laptop and scan again.',
    ),
    PhonePairingIssue.mismatch => (
      title: "Your laptop didn't answer as expected",
      fix: 'Update Sharely on both devices and try again.',
    ),
    PhonePairingIssue.noLaptopFound => (
      title: "Couldn't find your laptop",
      fix: 'Open Sharely on it and join the same Wi-Fi as this phone.',
    ),
    PhonePairingIssue.wrongCode => (
      title: "That code didn't match",
      fix: 'Check the code on your laptop; it changes every 5 minutes.',
    ),
  };
}
