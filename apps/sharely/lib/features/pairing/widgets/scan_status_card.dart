import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/features/pairing/state/phone_pairing_state.dart';

/// Below the viewfinder: a tip, progress, or a failure with one fix.
class ScanStatusCard extends StatelessWidget {
  const new({required this.state, required this.onScanAgain, super.key});

  final PhonePairingState state;
  final VoidCallback onScanAgain;

  @override
  Widget build(BuildContext context) {
    final (icon, message) = switch (state) {
      PhoneConnecting(:final laptopName) => (
        null,
        'Connecting to $laptopName…',
      ),
      PhonePairingFailed(:final issue) => (
        LucideIcons.circleAlert,
        failureMessage(issue),
      ),
      _ => (
        LucideIcons.wifi,
        'Your phone and laptop need to be on the same Wi-Fi network.',
      ),
    };
    return AnimatedSwitcher(
      duration: SharelyMotion.medium,
      child: DecoratedBox(
        key: ValueKey(message),
        decoration: const BoxDecoration(
          color: SharelyColors.surface,
          borderRadius: BorderRadius.all(Radius.circular(18)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(SharelySpacing.lg),
          child: Row(
            spacing: SharelySpacing.md,
            children: [
              _StatusIcon(icon),
              Expanded(child: Text(message)),
              if (state is PhonePairingFailed)
                TextButton(onPressed: onScanAgain, child: const Text('Retry')),
            ],
          ),
        ),
      ),
    );
  }

  static String failureMessage(PhonePairingIssue issue) => switch (issue) {
    PhonePairingIssue.notSharelyCode =>
      "That isn't a Sharely code. Scan the code shown in Sharely on your "
          'laptop.',
    PhonePairingIssue.unreachable =>
      "Can't reach your laptop. Join the same Wi-Fi, and allow Sharely "
          "through the laptop's firewall.",
    PhonePairingIssue.expiredCode =>
      'This code expired or was already used. Show a new code on your '
          'laptop and scan again.',
    PhonePairingIssue.mismatch =>
      "Your laptop didn't answer as expected. Update Sharely on both "
          'devices and try again.',
    PhonePairingIssue.noLaptopFound =>
      "Couldn't find your laptop. Open Sharely on it and join the same "
          'Wi-Fi as this phone.',
    PhonePairingIssue.wrongCode =>
      "That code didn't match. Check the code on your laptop; it changes "
          'every 5 minutes.',
  };
}

class _StatusIcon extends StatelessWidget {
  const new(this.icon);

  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final iconData = icon;
    return SizedBox.square(
      dimension: 24,
      child: iconData == null
          ? const CircularProgressIndicator(strokeWidth: 2.5)
          : Icon(iconData, color: SharelyColors.accent),
    );
  }
}
