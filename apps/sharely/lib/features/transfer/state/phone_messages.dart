import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sharely/features/transfer/state/transfer_receiver_provider.dart';
import 'package:sharely_core/sharely_core.dart';

/// Laptop side: validated messages from paired, connected phones.
final phoneMessagesProvider = Provider<Stream<ProtocolMessage>>(
  (ref) => ref
      .watch(transferReceiverProvider)
      .hub
      .messages
      .map((deviceMessage) => deviceMessage.message),
);
