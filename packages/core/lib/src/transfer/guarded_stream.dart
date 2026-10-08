import 'dart:async';

import 'package:sharely_core/src/transfer/resume_settings.dart';

/// A data stream broke off before its end; what arrived so far is kept.
class TransferInterrupted implements Exception {
  const new();

  @override
  String toString() => 'TransferInterrupted';
}

/// Passes [source] through, but ends it with [TransferInterrupted] as soon
/// as [interrupted] completes or no bytes arrive for [idleTimeout].
///
/// Without this a reader waits forever on a peer that silently lost Wi-Fi.
Stream<List<int>> guardStream(
  Stream<List<int>> source, {
  required Future<void> interrupted,
  Duration idleTimeout = defaultDataIdleTimeout,
}) {
  final relay = StreamController<List<int>>(sync: true);
  relay.onListen = () {
    late final StreamSubscription<List<int>> subscription;
    Timer? idleTimer;

    void breakOff() {
      idleTimer?.cancel();
      if (relay.isClosed) return;
      relay.addError(const TransferInterrupted());
      unawaited(relay.close());
      unawaited(subscription.cancel());
    }

    void restartIdleTimer() {
      idleTimer?.cancel();
      idleTimer = Timer(idleTimeout, breakOff);
    }

    subscription = source.listen(
      (chunk) {
        if (relay.isClosed) return;
        restartIdleTimer();
        relay.add(chunk);
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!relay.isClosed) relay.addError(error, stackTrace);
      },
      onDone: () {
        idleTimer?.cancel();
        if (!relay.isClosed) unawaited(relay.close());
      },
    );
    restartIdleTimer();
    unawaited(interrupted.then((_) => breakOff()));
    relay
      // A slow disk pauses the stream; that is not the peer going quiet.
      ..onPause = () {
        idleTimer?.cancel();
        subscription.pause();
      }
      ..onResume = () {
        restartIdleTimer();
        subscription.resume();
      }
      ..onCancel = () {
        idleTimer?.cancel();
        return subscription.cancel();
      };
  };
  return relay.stream;
}
