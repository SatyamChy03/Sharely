import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:sharely/app/storage/trust_store_provider.dart';
import 'package:sharely/features/pairing/state/laptop_pairing_state.dart';
import 'package:sharely/features/pairing/state/local_identity.dart';
import 'package:sharely/features/pairing/state/paired_devices.dart';
import 'package:sharely/features/transfer/state/transfer_receiver_provider.dart';
import 'package:sharely/features/transfer/state/transfer_sender_provider.dart';
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
  TlsIdentity? _identity;
  Timer? _expiryTimer;

  @override
  Future<LaptopPairingState> build() async {
    final address = await ref.watch(lanAddressProvider.future);
    if (address == null) return const LaptopNotOnNetwork();
    final localHello = await ref.watch(localHelloProvider.future);
    _localHello = localHello;
    // Kept across restarts of the server: phones pin this certificate.
    final identity = _identity ??= await _loadTlsIdentity();
    final server = await SharelyServer.start(
      address: address,
      identity: identity,
      pairingHandler: PairingRequestHandler(
        currentSession: () => _session,
        localHello: localHello,
        onPaired: _handlePhonePaired,
      ),
      transfers: (
        receiver: ref.read(transferReceiverProvider),
        sender: ref.read(transferSenderProvider),
        findPairedDevice: _findPairedDevice,
      ),
    );
    _server = server;
    _discovery = await _startDiscovery(server, localHello.deviceId);
    ref
      ..listen(pairedDevicesProvider, _dropRevokedDevices)
      ..onDispose(() {
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

  /// Withdraws the code on show, so it cannot be redeemed once hidden.
  void stopPairing() {
    if (state.value is! LaptopWaitingForPhone) return;
    final pairedDevices = ref.read(pairedDevicesProvider).value ?? const [];
    // With nothing paired the get-started screen still needs its code.
    if (pairedDevices.isEmpty) return;
    _expiryTimer?.cancel();
    _session = null;
    state = AsyncData(LaptopPairedWithPhone(pairedDevices.last));
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
        certFingerprint: _identity!.fingerprint,
        deviceId: _localHello.deviceId,
        deviceName: _localHello.deviceName,
      ),
      code: session.code,
      expiresAt: session.expiresAt,
    );
  }

  Future<TlsIdentity> _loadTlsIdentity() async {
    try {
      return await ref.read(trustStoreProvider).loadOrCreateTlsIdentity();
    } on PlatformException catch (error) {
      // Still encrypted this session; phones pair again after a restart.
      _log.severe('Secure storage is unavailable for the certificate', error);
      return TlsIdentity.generate();
    }
  }

  /// Lets a paired phone find this server after the address changes.
  Future<DiscoveryResponder?> _startDiscovery(
    SharelyServer server,
    String localDeviceId,
  ) async {
    try {
      return await DiscoveryResponder.start(
        localDeviceId: localDeviceId,
        serverEndpoint: DeviceEndpoint(
          host: server.address,
          port: server.port,
          certFingerprint: _identity!.fingerprint,
        ),
        findPairedDevice: _findPairedDevice,
      );
    } on SocketException catch (error) {
      // Pairing and transfers still work; only re-finding the laptop is lost.
      _log.warning('Discovery port is unavailable', error);
      return null;
    }
  }

  /// Removing a phone, or pairing it again, ends the connection its old
  /// token opened; new requests are already refused by [_findPairedDevice].
  void _dropRevokedDevices(
    AsyncValue<List<PairedDevice>>? before,
    AsyncValue<List<PairedDevice>> after,
  ) {
    final stillTrusted = {
      for (final device in after.value ?? const <PairedDevice>[])
        device.deviceId: device.authToken,
    };
    final hub = ref.read(transferReceiverProvider).hub;
    for (final device in before?.value ?? const <PairedDevice>[]) {
      if (stillTrusted[device.deviceId] != device.authToken) {
        hub.disconnect(device.deviceId);
      }
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
