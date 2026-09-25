import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mfm/src/extension/string_extension.dart';

/// 最適化前の実装。`tight` はこれと完全に同じ結果を返さなければならない。
String reference(String value) => Characters(value)
    .replaceAll(Characters(''), Characters('\u{200B}'))
    .toString();

void main() {
  const cases = [
    '',
    'a',
    'ab',
    '@user@example.tld',
    'https://example.com/notes/abc?q=1&r=2#hash',
    'misskey',
    'ひらがなカタカナ漢字',
    'é',
    'Áb', // 結合文字
    '👨‍👩‍👦x', // ZWJ 絵文字
    '🇯🇵🇺🇸', // 地域表示記号
    'a\r\nb', // CRLF は 1 つの grapheme cluster
    'tab\tと改行\n',
    'é́́',
  ];

  for (final value in cases) {
    test('tight は元実装と一致する: ${value.codeUnits}', () {
      expect(value.tight, reference(value));
    });
  }

  test('tight は2回目も同じ結果を返す（キャッシュ）', () {
    const value = '@user@example.tld';
    expect(value.tight, value.tight);
    expect(value.tight, reference(value));
  });

  test('キャッシュ上限を越えても正しい結果を返す', () {
    for (var i = 0; i < 700; i++) {
      final value = 'user$i@example.tld';
      expect(value.tight, reference(value));
    }
  });
}
