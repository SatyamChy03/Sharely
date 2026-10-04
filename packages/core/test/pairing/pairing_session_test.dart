import 'package:sharely_core/sharely_core.dart';
import 'package:test/test.dart';

void main() {
  var now = DateTime(2026, 10, 4, 12);
  PairingSession newSession() => PairingSession(clock: () => now);

  setUp(() => now = DateTime(2026, 10, 4, 12));

  test('code is six digits and token is a valid protocol id', () {
    final session = newSession();
    expect(session.code, matches(RegExp(r'^\d{6}$')));
    expect(isValidProtocolId(session.token), isTrue);
  });

  test('the QR token or the typed code redeems the session', () {
    final byToken = newSession();
    expect(byToken.redeem(byToken.token), isTrue);
    final byCode = newSession();
    expect(byCode.redeem(byCode.code), isTrue);
  });

  test('a session can be redeemed only once', () {
    final session = newSession();
    expect(session.redeem(session.token), isTrue);
    expect(session.redeem(session.token), isFalse);
    expect(session.isActive, isFalse);
  });

  test('locks after five wrong guesses, even for the right code', () {
    final session = newSession();
    for (var attempt = 0; attempt < 5; attempt++) {
      expect(session.redeem('000000x'), isFalse);
    }
    expect(session.redeem(session.code), isFalse);
  });

  test('expires after five minutes', () {
    final session = newSession();
    now = now.add(const Duration(minutes: 5, seconds: 1));
    expect(session.timeLeft, Duration.zero);
    expect(session.redeem(session.token), isFalse);
  });
}
