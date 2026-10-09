import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sharely/features/transfer/state/laptop_connection_controller.dart';
import 'package:sharely/features/transfer/state/laptop_connection_state.dart';
import 'package:sharely_core/sharely_core.dart';

/// Phone side: lets a paused transfer wait for the link to the laptop to
/// come back, at whatever address the laptop has by then.
final laptopReconnectProvider = Provider<PeerReconnect>((ref) {
  final restoredLinks = StreamController<PeerLink>.broadcast();
  ref
    ..listen(laptopConnectionProvider, (_, connection) {
      final link = _liveLink(connection);
      if (link != null) restoredLinks.add(link);
    })
    ..onDispose(restoredLinks.close);
  return (timeout) async {
    final current = _liveLink(ref.read(laptopConnectionProvider));
    if (current != null) return current;
    // A transfer is waiting, so skip what is left of the retry backoff.
    ref.read(laptopConnectionProvider.notifier).retryNow();
    try {
      // Null if the stream closes first: the app is shutting down.
      return await restoredLinks.stream
          .cast<PeerLink?>()
          .firstWhere((_) => true, orElse: () => null)
          .timeout(timeout);
    } on TimeoutException {
      return null;
    }
  };
});

PeerLink? _liveLink(LaptopConnectionState connection) {
  if (connection is! LaptopConnected) return null;
  final endpoint = connection.laptop.endpoint;
  if (endpoint == null || !connection.connection.isOpen) return null;
  return (connection: connection.connection, endpoint: endpoint);
}
