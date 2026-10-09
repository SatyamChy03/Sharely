import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sharely/features/transfer/state/transfer_receiver_provider.dart';
import 'package:sharely_core/sharely_core.dart';

/// The laptop's sending side; shares the receiver's control connections.
final transferSenderProvider = Provider<TransferSender>((ref) {
  final sender = TransferSender(hub: ref.watch(transferReceiverProvider).hub);
  ref.onDispose(() => unawaited(sender.close()));
  return sender;
});
