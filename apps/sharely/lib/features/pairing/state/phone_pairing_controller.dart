import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sharely/features/pairing/state/local_identity.dart';
import 'package:sharely/features/pairing/state/paired_devices.dart';
import 'package:sharely/features/pairing/state/phone_pairing_state.dart';
import 'package:sharely_core/sharely_core.dart';

final pairingClientProvider = Provider<PairingClient>(
  (ref) => const PairingClient(),
);

final phonePairingProvider =
    NotifierProvider<PhonePairingController, PhonePairingState>(
      PhonePairingController.new,
    );

/// Turns a scanned QR code into a trusted laptop.
class PhonePairingController extends Notifier<PhonePairingState> {
  @override
  PhonePairingState build() => const PhoneReadyToScan();

  Future<void> pairWithScannedCode(String scannedText) async {
    if (state is PhoneConnecting || state is PhonePaired) return;
    final PairingInvite invite;
    try {
      invite = PairingInvite.parse(scannedText);
    } on ProtocolException {
      state = const PhonePairingFailed(PhonePairingIssue.notSharelyCode);
      return;
    }
    state = PhoneConnecting(invite.deviceName);
    try {
      final localHello = await ref.read(localHelloProvider.future);
      final laptop = await ref
          .read(pairingClientProvider)
          .pair(invite: invite, localHello: localHello);
      if (!ref.mounted) return;
      ref.read(pairedDevicesProvider.notifier).trust(laptop);
      state = PhonePaired(laptop);
    } on PairingException catch (error) {
      if (!ref.mounted) return;
      state = PhonePairingFailed(_issueFor(error.failure));
    }
  }

  void scanAgain() => state = const PhoneReadyToScan();

  PhonePairingIssue _issueFor(PairingFailure failure) => switch (failure) {
    PairingFailure.unreachable => PhonePairingIssue.unreachable,
    PairingFailure.rejected => PhonePairingIssue.expiredCode,
    PairingFailure.invalidResponse => PhonePairingIssue.mismatch,
  };
}
