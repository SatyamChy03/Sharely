import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sharely/features/pairing/state/local_identity.dart';
import 'package:sharely/features/pairing/state/paired_devices.dart';
import 'package:sharely/features/pairing/state/phone_pairing_state.dart';
import 'package:sharely_core/sharely_core.dart';

final _pairingCodePattern = RegExp(r'^\d{6}$');

final pairingClientProvider = Provider<PairingClient>(
  (ref) => const PairingClient(),
);

/// Overridden in tests, which have no Wi-Fi to sweep.
final laptopFinderProvider = Provider<LaptopFinder>(
  (ref) => const LaptopFinder(),
);

final phonePairingProvider =
    NotifierProvider<PhonePairingController, PhonePairingState>(
      PhonePairingController.new,
    );

/// Turns a scanned QR code, or a typed 6-digit code, into a trusted laptop.
class PhonePairingController extends Notifier<PhonePairingState> {
  @override
  PhonePairingState build() => const PhoneReadyToScan();

  bool get _isBusy =>
      state is PhoneConnecting ||
      state is PhoneSearchingForLaptop ||
      state is PhonePaired;

  Future<void> pairWithScannedCode(String scannedText) async {
    if (_isBusy) return;
    final PairingInvite invite;
    try {
      invite = PairingInvite.parse(scannedText);
    } on ProtocolException {
      state = const PhonePairingFailed(PhonePairingIssue.notSharelyCode);
      return;
    }
    await _pair(invite, rejectedIssue: PhonePairingIssue.expiredCode);
  }

  /// Finds the laptop on this Wi-Fi, then redeems [code] on it.
  Future<void> pairWithTypedCode(String code) async {
    if (_isBusy || !_pairingCodePattern.hasMatch(code)) return;
    state = const PhoneSearchingForLaptop();
    final laptops = await ref.read(laptopFinderProvider).findOnLocalNetwork();
    if (!ref.mounted) return;
    if (laptops.isEmpty) {
      state = const PhonePairingFailed(PhonePairingIssue.noLaptopFound);
      return;
    }
    // Several laptops: the user picks, so the code only goes to theirs.
    if (laptops.length > 1) {
      state = PhoneChoosingLaptop(laptops, code);
      return;
    }
    await pairWithFoundLaptop(laptops.single, code);
  }

  Future<void> pairWithFoundLaptop(FoundLaptop laptop, String code) {
    final invite = PairingInvite(
      host: laptop.endpoint.host,
      port: laptop.endpoint.port,
      token: code,
      deviceId: laptop.hello.deviceId,
      deviceName: laptop.hello.deviceName,
    );
    return _pair(invite, rejectedIssue: PhonePairingIssue.wrongCode);
  }

  void scanAgain() => state = const PhoneReadyToScan();

  Future<void> _pair(
    PairingInvite invite, {
    required PhonePairingIssue rejectedIssue,
  }) async {
    state = PhoneConnecting(invite.deviceName);
    try {
      final localHello = await ref.read(localHelloProvider.future);
      final laptop = await ref
          .read(pairingClientProvider)
          .pair(invite: invite, localHello: localHello);
      if (!ref.mounted) return;
      await ref.read(pairedDevicesProvider.notifier).trust(laptop);
      if (!ref.mounted) return;
      state = PhonePaired(laptop);
    } on PairingException catch (error) {
      if (!ref.mounted) return;
      state = PhonePairingFailed(switch (error.failure) {
        PairingFailure.unreachable => PhonePairingIssue.unreachable,
        PairingFailure.rejected => rejectedIssue,
        PairingFailure.invalidResponse => PhonePairingIssue.mismatch,
      });
    }
  }
}
