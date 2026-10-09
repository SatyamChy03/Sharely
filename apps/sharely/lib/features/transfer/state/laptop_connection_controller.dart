import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sharely/features/pairing/state/local_identity.dart';
import 'package:sharely/features/pairing/state/paired_devices.dart';
import 'package:sharely/features/transfer/state/laptop_connection_state.dart';
import 'package:sharely_core/sharely_core.dart';

// Backs off so a laptop that is off doesn't drain the phone's battery.
const _retryDelays = [2, 4, 8, 15, 30];

typedef ControlConnector = Future<ControlConnection> Function(
  DeviceEndpoint endpoint,
  Map<String, String> authHeaders,
);

// A laptop on the same Wi-Fi answers at once; waiting longer only delays
// looking for it at a new address.
const _connectTimeout = Duration(seconds: 4);

/// Overridden in tests to connect without a real laptop.
final controlConnectorProvider = Provider<ControlConnector>(
  (ref) =>
      (endpoint, authHeaders) => ControlConnection.connect(
        endpoint,
        authHeaders: authHeaders,
        timeout: _connectTimeout,
      ),
);

typedef LaptopAddressLookup = Future<DeviceEndpoint?> Function(
  PairedDevice laptop,
  String localDeviceId,
);

/// Asks the Wi-Fi where the laptop is now. Overridden in tests.
final laptopAddressLookupProvider = Provider<LaptopAddressLookup>(
  (ref) =>
      (laptop, localDeviceId) => const LaptopLocator().locate(
        laptop: laptop,
        localDeviceId: localDeviceId,
      ),
);

final laptopConnectionProvider =
    NotifierProvider<LaptopConnectionController, LaptopConnectionState>(
      LaptopConnectionController.new,
    );

/// Keeps the phone connected to its active laptop while the app is open.
///
/// The active laptop is the last one in the paired list; pairing or
/// choosing a laptop moves it there.
class LaptopConnectionController extends Notifier<LaptopConnectionState> {
  ControlConnection? _connection;
  // By id, so pairing or choosing another laptop connects straight away.
  String? _disconnectedLaptopId;
  int _buildCount = 0;
  Timer? _retryTimer;
  int _failedAttempts = 0;

  @override
  LaptopConnectionState build() {
    // Only what the link depends on, so changing a setting such as "always
    // accept" doesn't drop the connection in the middle of a transfer.
    ref.watch(
      pairedDevicesProvider.select((devices) {
        final laptop = devices.value?.lastOrNull;
        return (laptop?.deviceId, laptop?.authToken, laptop?.endpoint);
      }),
    );
    final devices = ref.read(pairedDevicesProvider).value ?? const [];
    final laptop = devices.lastOrNull;
    // Connects started for an earlier laptop, or before a disconnect, must
    // not land on this build's state.
    final build = ++_buildCount;
    ref.onDispose(() {
      _retryTimer?.cancel();
      final connection = _connection;
      // Cleared first, so its closing isn't mistaken for a lost link.
      _connection = null;
      unawaited(connection?.close());
    });
    if (laptop == null) return const LaptopNotPaired();
    if (laptop.endpoint == null) return LaptopNeedsRepairing(laptop);
    if (laptop.deviceId == _disconnectedLaptopId) {
      return LaptopDisconnected(laptop);
    }
    unawaited(Future.microtask(() => _connect(laptop, build)));
    return LaptopConnecting(laptop);
  }

  /// Closes the link to the active laptop and stays off it until [connect].
  /// The pairing is kept. Lasts until the app is closed.
  void disconnect() {
    final laptop = _activeLaptop;
    if (laptop == null) return;
    _disconnectedLaptopId = laptop.deviceId;
    ref.invalidateSelf();
  }

  /// Undoes [disconnect]; also retries at once if the laptop was unreachable.
  void connect() {
    if (_disconnectedLaptopId == null) return retryNow();
    _disconnectedLaptopId = null;
    ref.invalidateSelf();
  }

  PairedDevice? get _activeLaptop =>
      (ref.read(pairedDevicesProvider).value ?? const []).lastOrNull;

  /// Skips the backoff, e.g. when the app comes back to the foreground.
  void retryNow() {
    final current = state;
    if (current is! LaptopUnreachable) return;
    _retryTimer?.cancel();
    state = LaptopConnecting(current.laptop);
    unawaited(_connect(current.laptop, _buildCount));
  }

  Future<void> _connect(PairedDevice laptop, int build) async {
    final endpoint = laptop.endpoint;
    if (endpoint == null) return;
    final localHello = await ref.read(localHelloProvider.future);
    bool isStale() => !ref.mounted || build != _buildCount;
    try {
      final connection = await ref.read(controlConnectorProvider)(
        endpoint,
        buildAuthHeaders(
          localDeviceId: localHello.deviceId,
          authToken: laptop.authToken,
        ),
      );
      if (isStale()) return unawaited(connection.close());
      _adopt(laptop, connection);
    } on TransferException {
      if (isStale()) return;
      if (await _followLaptopToNewAddress(laptop, localHello.deviceId)) return;
      if (isStale()) return;
      state = LaptopUnreachable(laptop);
      _scheduleRetry(laptop);
    }
  }

  /// Routers reassign addresses, so a silent laptop may only have moved.
  /// Saving the new address rebuilds this controller, which reconnects.
  Future<bool> _followLaptopToNewAddress(
    PairedDevice laptop,
    String localDeviceId,
  ) async {
    final current = await ref.read(laptopAddressLookupProvider)(
      laptop,
      localDeviceId,
    );
    if (!ref.mounted || current == null || current == laptop.endpoint) {
      return false;
    }
    await ref
        .read(pairedDevicesProvider.notifier)
        .trust(laptop.copyWith(endpoint: current));
    return true;
  }

  void _adopt(PairedDevice laptop, ControlConnection connection) {
    _connection = connection;
    _failedAttempts = 0;
    state = LaptopConnected(laptop, connection);
    unawaited(
      connection.done.then((_) {
        if (!ref.mounted || !identical(_connection, connection)) return;
        _connection = null;
        state = LaptopUnreachable(laptop);
        _scheduleRetry(laptop);
      }),
    );
  }

  void _scheduleRetry(PairedDevice laptop) {
    final delay =
        _retryDelays[_failedAttempts.clamp(0, _retryDelays.length - 1)];
    _failedAttempts++;
    _retryTimer?.cancel();
    _retryTimer = Timer(Duration(seconds: delay), () {
      if (!ref.mounted || state is! LaptopUnreachable) return;
      state = LaptopConnecting(laptop);
      unawaited(_connect(laptop, _buildCount));
    });
  }
}
