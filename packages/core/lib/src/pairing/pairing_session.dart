import 'dart:math';

import 'package:sharely_core/src/security/constant_time.dart';
import 'package:sharely_core/src/security/secure_id.dart';

/// One pairing window on the laptop: the QR token and the 6-digit code.
///
/// Single use, short lived, and locked after a few wrong guesses, so the
/// one-in-a-million code cannot be brute forced on a shared network.
class PairingSession {
  new({
    DateTime Function()? clock,
    this.lifetime = const Duration(minutes: 5),
    this.maxFailedAttempts = 5,
  }) : _clock = clock ?? DateTime.now,
       token = generateSecureId(),
       code = _generatePairingCode() {
    expiresAt = _clock().add(lifetime);
  }

  final DateTime Function() _clock;
  final Duration lifetime;
  final int maxFailedAttempts;
  final String token;
  final String code;
  late final DateTime expiresAt;

  int _failedAttempts = 0;
  bool _isRedeemed = false;

  bool get isRedeemed => _isRedeemed;

  bool get isActive =>
      !_isRedeemed &&
      _failedAttempts < maxFailedAttempts &&
      _clock().isBefore(expiresAt);

  Duration get timeLeft {
    final remaining = expiresAt.difference(_clock());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Accepts the QR token or the typed code exactly once.
  bool redeem(String secret) {
    if (!isActive) return false;
    // Both comparisons always run so timing does not reveal which matched.
    final matchesToken = constantTimeEquals(secret, token);
    final matchesCode = constantTimeEquals(secret, code);
    if (matchesToken || matchesCode) {
      _isRedeemed = true;
      return true;
    }
    _failedAttempts++;
    return false;
  }

  static String _generatePairingCode() {
    return Random.secure().nextInt(1000000).toString().padLeft(6, '0');
  }
}
