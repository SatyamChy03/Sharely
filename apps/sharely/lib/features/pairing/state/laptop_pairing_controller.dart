import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sharely/features/pairing/state/laptop_pairing_state.dart';
import 'package:sharely/features/pairing/state/local_identity.dart';
import 'package:sharely/features/pairing/state/paired_devices.dart';
import 'package:sharely_core/sharely_core.dart';

/// Which address the laptop serves on. Overridable so tests use loopback.
final lanAddressProvider = FutureProvider<InternetAddress?>((ref) async {
  final addresses = await findLanAddresses();
  return addresses.isEmpty ? null : addresses.first;
});

final laptopPairingProvider =
    AsyncNotifierProvider<LaptopPairingController, LaptopPairingState>(
      LaptopPairingController.new,
    );

/// Runs the laptop's server and rotates the one-time pairing session.
class LaptopPairingController extends AsyncNotifier<LaptopPairingState> {
  PairingSession? _session;
  SharelyServer? _server;
  late HelloMessage _localHello;
  Timer? _expiryTimer;

  @override
  Future<LaptopPairingState> build() async {
    final address = await ref.watch(lanAddressProvider.future);
    if (address == null) return const LaptopNotOnNetwork();
    final localHello = await ref.watch(localHelloProvider.future);
    _localHello = localHello;
    final server = await SharelyServer.start(
      address: address,
      pairingHandler: PairingRequestHandler(
        currentSession: () => _session,
        localHello: localHello,
        onPaired: _handlePhonePaired,
      ),
    );
    _server = server;
    ref.onDispose(() {
      _expiryTimer?.cancel();
      unawaited(server.stop());
    });
    final pairedDevices = await ref.read(pairedDevicesProvider.future);
    if (pairedDevices.isNotEmpty) {
      return LaptopPairedWithPhone(pairedDevices.last);
    }
    return _startWaiting();
  }

  /// Shows a fresh QR code and code, invalidating the previous ones.
  void showNewCode() {
    if (_server == null) return;
    state = AsyncData(_startWaiting());
  }

  LaptopPairingState _startWaiting() {
    final session = PairingSession();
    _session = session;
    _expiryTimer?.cancel();
    _expiryTimer = Timer(session.lifetime, showNewCode);
    return LaptopWaitingForPhone(
      invite: PairingInvite(
        host: _server!.address,
        port: _server!.port,
        token: session.token,
        deviceId: _localHello.deviceId,
        deviceName: _localHello.deviceName,
      ),
      code: session.code,
      expiresAt: session.expiresAt,
    );
  }

  void _handlePhonePaired(PairedDevice phone) {
    _expiryTimer?.cancel();
    _session = null;
    unawaited(ref.read(pairedDevicesProvider.notifier).trust(phone));
    state = AsyncData(LaptopPairedWithPhone(phone));
  }
}
