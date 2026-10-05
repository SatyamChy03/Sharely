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

/// Overridden in tests to connect without a real laptop.
final controlConnectorProvider = Provider<ControlConnector>(
  (ref) =>
      (endpoint, authHeaders) =>
          ControlConnection.connect(endpoint, authHeaders: authHeaders),
);

final laptopConnectionProvider =
    NotifierProvider<LaptopConnectionController, LaptopConnectionState>(
      LaptopConnectionController.new,
    );

/// Keeps the phone connected to its paired laptop while the app is open.
class LaptopConnectionController extends Notifier<LaptopConnectionState> {
  ControlConnection? _connection;
  Timer? _retryTimer;
  int _failedAttempts = 0;

  @override
  LaptopConnectionState build() {
    final devices = ref.watch(pairedDevicesProvider).value ?? const [];
    final laptop = devices.lastOrNull;
    ref.onDispose(() {
      _retryTimer?.cancel();
      unawaited(_connection?.close());
    });
    if (laptop == null) return const LaptopNotPaired();
    if (laptop.endpoint == null) return LaptopNeedsRepairing(laptop);
    unawaited(Future.microtask(() => _connect(laptop)));
    return LaptopConnecting(laptop);
  }

  /// Skips the backoff, e.g. when the app comes back to the foreground.
  void retryNow() {
    final current = state;
    if (current is! LaptopUnreachable) return;
    _retryTimer?.cancel();
    state = LaptopConnecting(current.laptop);
    unawaited(_connect(current.laptop));
  }

  Future<void> _connect(PairedDevice laptop) async {
    final endpoint = laptop.endpoint;
    if (endpoint == null) return;
    try {
      final localHello = await ref.read(localHelloProvider.future);
      final connection = await ref.read(controlConnectorProvider)(
        endpoint,
        buildAuthHeaders(
          localDeviceId: localHello.deviceId,
          authToken: laptop.authToken,
        ),
      );
      if (!ref.mounted) return unawaited(connection.close());
      _adopt(laptop, connection);
    } on TransferException {
      if (!ref.mounted) return;
      state = LaptopUnreachable(laptop);
      _scheduleRetry(laptop);
    }
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
      unawaited(_connect(laptop));
    });
  }
}
