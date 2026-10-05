import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:sharely/app/storage/trust_store_provider.dart';
import 'package:sharely_core/sharely_core.dart';

final _log = Logger('PairedDevices');

final pairedDevicesProvider =
    AsyncNotifierProvider<PairedDevicesNotifier, List<PairedDevice>>(
      PairedDevicesNotifier.new,
    );

/// Devices this one trusts, kept in the platform's secure storage.
class PairedDevicesNotifier extends AsyncNotifier<List<PairedDevice>> {
  TrustStore get _store => ref.read(trustStoreProvider);

  @override
  Future<List<PairedDevice>> build() async {
    try {
      return await _store.loadPairedDevices();
    } on TrustStoreException catch (error) {
      // Unreadable trust data is never used; the user simply pairs again.
      _log.warning('Discarding unreadable paired devices', error);
      await _store.forgetPairedDevices();
      return const [];
    } on PlatformException catch (error) {
      _log.severe('Secure storage is unavailable', error);
      return const [];
    }
  }

  /// Re-pairing the same device replaces its old record and token.
  Future<void> trust(PairedDevice device) async {
    final current = await future;
    final updated = [
      for (final existing in current)
        if (existing.deviceId != device.deviceId) existing,
      device,
    ];
    // Past the storage limit, the oldest pairings make room for the newest.
    final overflow = max(0, updated.length - maxStoredPairedDevices);
    final kept = List<PairedDevice>.unmodifiable(updated.skip(overflow));
    if (!ref.mounted) return;
    state = AsyncData(kept);
    await _saveOrKeepInMemory(kept);
  }

  Future<void> _saveOrKeepInMemory(List<PairedDevice> devices) async {
    try {
      await _store.savePairedDevices(devices);
    } on PlatformException catch (error) {
      // The pairing still works this session; it just won't survive a restart.
      _log.severe('Could not save paired devices securely', error);
    }
  }
}
