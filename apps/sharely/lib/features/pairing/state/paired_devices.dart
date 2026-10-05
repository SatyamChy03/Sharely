import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sharely_core/sharely_core.dart';

final pairedDevicesProvider =
    NotifierProvider<PairedDevicesNotifier, List<PairedDevice>>(
      PairedDevicesNotifier.new,
    );

/// Devices trusted this session. Secure persistence lands in a later step.
class PairedDevicesNotifier extends Notifier<List<PairedDevice>> {
  @override
  List<PairedDevice> build() => const [];

  /// Re-pairing the same device replaces its old record and token.
  void trust(PairedDevice device) {
    state = List.unmodifiable([
      for (final existing in state)
        if (existing.deviceId != device.deviceId) existing,
      device,
    ]);
  }
}
