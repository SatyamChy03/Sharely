import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sharely/features/transfer/state/transfer_receiver_provider.dart';

final connectedPhonesProvider = NotifierProvider<ConnectedPhones, Set<String>>(
  ConnectedPhones.new,
);

/// Laptop side: ids of paired phones with a live control connection.
class ConnectedPhones extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    final hub = ref.watch(transferReceiverProvider).hub;
    final subscriptions = [
      hub.connects.listen((id) => state = {...state, id}),
      hub.disconnects.listen((id) => state = {...state}..remove(id)),
    ];
    ref.onDispose(() {
      for (final subscription in subscriptions) {
        subscription.cancel().ignore();
      }
    });
    return const {};
  }
}
