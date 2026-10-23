import 'dart:convert';

import 'package:sharely_core/sharely_core.dart';
import 'package:test/test.dart';

void main() {
  group('sanitizeFileName', () {
    final expectations = {
      'photo.jpg': 'photo.jpg',
      '../../etc/passwd': 'passwd',
      r'..\..\Windows\System32\evil.dll': 'evil.dll',
      '/absolute/path/report.pdf': 'report.pdf',
      '..': 'file',
      '': 'file',
      '   ': 'file',
      '.bashrc': 'bashrc',
      'notes.txt.': 'notes.txt',
      'CON': '_CON',
      'con.txt': '_con.txt',
      'LPT1.log': '_LPT1.log',
      'a<b>c:d"e|f?g*h.txt': 'a_b_c_d_e_f_g_h.txt',
      'tab\there.txt': 'tab_here.txt',
      'résumé 2026.pdf': 'résumé 2026.pdf',
    };
    for (final MapEntry(key: input, value: expected) in expectations.entries) {
      test('"$input" becomes "$expected"', () {
        expect(sanitizeFileName(input), expected);
      });
    }

    test('strips right-to-left override used to fake extensions', () {
      final rightToLeftOverride = String.fromCharCode(0x202E);
      final disguised = 'invoice${rightToLeftOverride}gpj.exe';
      expect(sanitizeFileName(disguised), 'invoicegpj.exe');
    });

    test('strips the Arabic letter mark, another direction control', () {
      final arabicLetterMark = String.fromCharCode(0x061C);
      expect(sanitizeFileName('a${arabicLetterMark}b.txt'), 'ab.txt');
    });

    test('replaces invisible control and line-break characters', () {
      final hidden = [0x85, 0x9B, 0x2028, 0x2029].map(String.fromCharCode);
      for (final character in hidden) {
        expect(sanitizeFileName('a${character}b.txt'), 'a_b.txt');
      }
    });

    test('limits long names to 240 bytes and keeps the extension', () {
      final result = sanitizeFileName('${'é' * 300}.pdf');
      expect(utf8.encode(result).length, lessThanOrEqualTo(240));
      expect(result, endsWith('.pdf'));
    });
  });
}
