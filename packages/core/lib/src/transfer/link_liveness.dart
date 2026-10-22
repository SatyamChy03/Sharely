import 'dart:async';

/// How often each end asks the other to answer on the control channel.
const controlPingInterval = Duration(seconds: 3);

/// How long a peer that is on screen may stay silent before the link is
/// taken for lost. With [controlPingInterval] a dead link is noticed
/// within about 13 seconds.
const controlSilenceLimit = Duration(seconds: 10);

/// How long a phone that said Sharely is off its screen may stay silent.
/// Long enough to pick a file or glance at another app; a phone that
/// closes the app still ends the link at once, by closing its socket.
const backgroundSilenceLimit = Duration(minutes: 2);

/// Reads the time. Injected so tests can stand in for a paused device.
typedef LivenessClock = DateTime Function();

/// Decides when a quiet link is dead, without blaming the peer for time
/// this device itself spent paused.
///
/// Built on its own clock rather than the socket's ping timer: that timer
/// closes the link when a paused app wakes, before the waiting answer is
/// even read.
class LinkLiveness {
  new({
    required this.sendPing,
    required this.closeAsDead,
    LivenessClock? clock,
    this.checkEvery = controlPingInterval,
    this.allowedSilence = controlSilenceLimit,
  }) : _clock = clock ?? DateTime.now {
    _lastHeard = _lastCheck = _clock();
    _timer = Timer.periodic(checkEvery, (_) => _check());
  }

  final void Function() sendPing;
  final void Function() closeAsDead;
  final Duration checkEvery;
  final LivenessClock _clock;

  /// Raised while the peer is known to be paused; see [backgroundSilenceLimit].
  Duration allowedSilence;

  late DateTime _lastHeard;
  late DateTime _lastCheck;
  late final Timer _timer;

  /// Any frame from the peer, a message or an answer, proves it is there.
  void recordHeard() => _lastHeard = _clock();

  void stop() => _timer.cancel();

  void _check() {
    final now = _clock();
    final sinceLastCheck = now.difference(_lastCheck);
    _lastCheck = now;
    // This device was paused (a frozen app, a sleeping laptop): the peer's
    // answers may be waiting unread, so it gets a fresh chance.
    if (sinceLastCheck > checkEvery * 2) _lastHeard = now;
    if (now.difference(_lastHeard) > allowedSilence) {
      stop();
      return closeAsDead();
    }
    sendPing();
  }
}
