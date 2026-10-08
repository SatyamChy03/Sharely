import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sharely/features/transfer/state/laptop_connection_controller.dart';
import 'package:sharely/features/transfer/state/laptop_connection_state.dart';
import 'package:sharely_core/sharely_core.dart';

/// Phone side: validated messages from the laptop, across reconnects.
final laptopMessagesProvider = Provider<Stream<ProtocolMessage>>((ref) {
  final messages = StreamController<ProtocolMessage>.broadcast();
  StreamSubscription<ProtocolMessage>? current;
  ref
    ..listen(laptopConnectionProvider, (_, connection) {
      unawaited(current?.cancel());
      current = connection is LaptopConnected
          ? connection.connection.messages.listen(messages.add)
          : null;
    }, fireImmediately: true)
    ..onDispose(() {
      unawaited(current?.cancel());
      unawaited(messages.close());
    });
  return messages.stream;
});
