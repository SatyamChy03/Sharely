import 'package:sharely_core/sharely_core.dart';
import 'package:test/test.dart';

void main() {
  test('equal secrets match', () {
    expect(constantTimeEquals('482913', '482913'), isTrue);
  });

  test('different secrets, lengths and empty strings do not match', () {
    expect(constantTimeEquals('482913', '482914'), isFalse);
    expect(constantTimeEquals('482913', '4829130'), isFalse);
    expect(constantTimeEquals('', '482913'), isFalse);
  });
}
