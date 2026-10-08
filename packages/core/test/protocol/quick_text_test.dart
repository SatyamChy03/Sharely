import 'package:sharely_core/sharely_core.dart';
import 'package:test/test.dart';

void main() {
  test('a single web address becomes a link', () {
    final message = composeQuickText('  https://example.com/a?b=1  ');

    expect(message, isA<LinkMessage>());
    expect(
      (message as LinkMessage).url.toString(),
      'https://example.com/a?b=1',
    );
  });

  test('an OTP or a note stays plain text', () {
    for (final text in ['482913', 'Meet at 5', 'see https://example.com now']) {
      final message = composeQuickText(text);

      expect(message, isA<TextContentMessage>(), reason: text);
      expect((message as TextContentMessage).body, text);
      expect(message.type, MessageType.text);
    }
  });

  test('log lines keep their line breaks and indentation', () {
    const log = '  at main (app.dart:3)\n\tat run (zone.dart:9)\n';

    expect((composeQuickText(log) as TextContentMessage).body, log);
  });

  test('unsafe schemes are sent as text, never as a link', () {
    for (final text in [
      'javascript:alert(1)',
      'file:///etc/passwd',
      'intent://scan/#Intent;end',
      'https://user:pass@example.com',
    ]) {
      expect(composeQuickText(text), isA<TextContentMessage>(), reason: text);
    }
  });

  test('empty or blank input is refused', () {
    for (final text in ['', '   ', '\n\t']) {
      expect(() => composeQuickText(text), throwsA(isA<ProtocolException>()));
    }
  });

  test('text past the limit is refused instead of sent', () {
    final tooLong = 'a' * (ProtocolLimits.maxTextChars + 1);
    // Each control character takes six once encoded, passing the frame limit.
    final tooLongEncoded = '\u0001' * ProtocolLimits.maxTextChars;

    expect(() => composeQuickText(tooLong), throwsA(isA<ProtocolException>()));
    expect(
      () => composeQuickText(tooLongEncoded),
      throwsA(isA<ProtocolException>()),
    );
    expect(composeQuickText('a' * ProtocolLimits.maxTextChars), isNotNull);
  });

  test('text with a NUL character is refused', () {
    expect(
      () => composeQuickText('a\u0000b'),
      throwsA(isA<ProtocolException>()),
    );
  });
}
