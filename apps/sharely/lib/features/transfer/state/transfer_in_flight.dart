import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sharely/features/transfer/state/incoming_transfer_view.dart';
import 'package:sharely/features/transfer/state/laptop_offers_controller.dart';
import 'package:sharely/features/transfer/state/send_controller.dart';
import 'package:sharely/features/transfer/state/send_state.dart';

/// Phone side: whether files are moving right now, in either direction.
/// Changing or dropping the laptop then would break the transfer.
final isTransferInFlightProvider = Provider<bool>((ref) {
  final send = ref.watch(sendProvider);
  final isSending =
      send is SendPreparing ||
      send is SendAwaitingAcceptance ||
      send is SendInProgress;
  final isReceiving = ref
      .watch(laptopOffersProvider)
      .any((view) => view.stage == IncomingTransferStage.receiving);
  return isSending || isReceiving;
});
