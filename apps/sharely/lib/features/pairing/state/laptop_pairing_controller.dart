import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:sharely/features/pairing/state/laptop_pairing_state.dart';
import 'package:sharely/features/pairing/state/local_identity.dart';
import 'package:sharely/features/pairing/state/paired_devices.dart';
import 'package:sharely/features/transfer/state/transfer_receiver_provider.dart';
import 'package:sharely_core/sharely_core.dart';

final _log = Logger('LaptopPairing');

const _addressCheckInterval = Duration(seconds: 5);

/// Which address the laptop serves on. Overridable so tests use loopback.
///
/// Routers hand out new addresses over time, so this re-resolves whenever
/// the current one disappears; the server then restarts on the new one.
final lanAddressProvider = FutureProvider<InternetAddress?>((ref) async {
  final address = (await findLanAddresses()).firstOrNull;
  final addressCheck = Timer.periodic(_addressCheckInterval, (_) async {
    final latest = await findLanAddresses();
    if (!ref.mounted) return;
    final isStillValid = address == null
        ? latest.isEmpty
        : latest.contains(address);
    if (!isStillValid) ref.invalidateSelf();
  });
  ref.onDispose(addressCheck.cancel);
  return address;
});

final laptopPairingProvider =
    AsyncNotifierProvider<LaptopPairingController, LaptopPairingState>(
      LaptopPairingController.new,
    );

/// Runs the laptop's server and rotates the one-time pairing session.
class LaptopPairingController extends AsyncNotifier<LaptopPairingState> {
  PairingSession? _session;
  SharelyServer? _server;
  DiscoveryResponder? _discovery;
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
      transfers: (
        receiver: ref.read(transferReceiverProvider),
        findPairedDevice: _findPairedDevice,
      ),
    );
    _server = server;
    _discovery = await _startDiscovery(server, localHello.deviceId);
    ref.onDispose(() {
      _expiryTimer?.cancel();
      _discovery?.stop();
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

  /// Lets a paired phone find this server after the address changes.
  Future<DiscoveryResponder?> _startDiscovery(
    SharelyServer server,
    String localDeviceId,
  ) async {
    try {
      return await DiscoveryResponder.start(
        localDeviceId: localDeviceId,
        serverEndpoint: DeviceEndpoint(host: server.address, port: server.port),
        findPairedDevice: _findPairedDevice,
      );
    } on SocketException catch (error) {
      // Pairing and transfers still work; only re-finding the laptop is lost.
      _log.warning('Discovery port is unavailable', error);
      return null;
    }
  }

  // Read on every request, so a device removed from the list loses access.
  PairedDevice? _findPairedDevice(String deviceId) {
    final devices = ref.read(pairedDevicesProvider).value ?? const [];
    return devices.where((device) => device.deviceId == deviceId).firstOrNull;
  }

  void _handlePhonePaired(PairedDevice phone) {
    _expiryTimer?.cancel();
    _session = null;
    unawaited(ref.read(pairedDevicesProvider.notifier).trust(phone));
    state = AsyncData(LaptopPairedWithPhone(phone));
  }
}
