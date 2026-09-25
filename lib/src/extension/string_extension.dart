import 'package:flutter/widgets.dart';

/// [StringExtensions.tight] の結果キャッシュ。
///
/// mention / hashtag / URL は再ビルドごとに同じ文字列へ `tight` がかかるため、
/// grapheme 分割をやり直さずに済むよう控えめな上限付きでキャッシュする。
final Map<String, String> _tightCache = {};

/// キャッシュの上限。タイムライン数画面ぶんの mention / URL が入る程度。
const int _tightCacheLimit = 512;

/// [_tightFast] で扱える文字の範囲（表示可能な ASCII）。
/// この範囲の文字は必ず 1 文字が 1 つの grapheme cluster になるので、
/// `characters` を通さずに組み立てられる。`\r\n` のような複数コードユニットで
/// 1 cluster になる組み合わせを避けるため、制御文字は除外している。
bool _isFastAscii(String value) {
  for (var i = 0; i < value.length; i++) {
    final c = value.codeUnitAt(i);
    if (c < 0x20 || c > 0x7E) return false;
  }
  return true;
}

String _tightFast(String value) {
  final buffer = StringBuffer();
  for (var i = 0; i < value.length; i++) {
    buffer.writeCharCode(0x200B);
    buffer.writeCharCode(value.codeUnitAt(i));
  }
  buffer.writeCharCode(0x200B);
  return buffer.toString();
}

String _tightSlow(String value) {
  return Characters(value)
      .replaceAll(Characters(''), Characters('\u{200B}'))
      .toString();
}

extension StringExtensions on String {
  /// grapheme cluster の境界すべてに ZWSP を挟み、どこでも折り返せるようにする。
  String get tight {
    if (isEmpty) return '\u{200B}';

    final cached = _tightCache[this];
    if (cached != null) return cached;

    final result = _isFastAscii(this) ? _tightFast(this) : _tightSlow(this);

    if (_tightCache.length >= _tightCacheLimit) {
      _tightCache.clear();
    }
    _tightCache[this] = result;
    return result;
  }

  String get decodeUri {
    try {
      return Uri.decodeComponent(this);
    } catch (e) {
      return this;
    }
  }

  String get nyaize {
    return // ja-JP
        replaceAll('な', 'にゃ')
            .replaceAll('ナ', 'ニャ')
            .replaceAll('ﾅ', 'ﾆｬ')
            // en-US
            .replaceAllMapped(
                RegExp("(?<=[nN])[aA]"), (x) => x.group(0) == 'A' ? 'YA' : 'ya')
            .replaceAllMapped(RegExp("(?<=morn)ing"),
                (x) => x.group(0) == "ING" ? "YAN" : "yan")
            .replaceAllMapped(RegExp("(?<=every)one"),
                (x) => x.group(0) == "ONE" ? "NYAN" : "nyan");
    // TODO: support ko-KR
    //   .replaceAllMapped(RegExp("[나-낳]"), (match) => )
    // // ko-KR
    //     .replace(//g, match => String.fromCharCode(
    // match.charCodeAt(0)! + '냐'.charCodeAt(0) - '나'.charCodeAt(0),
    // ))
    //     .replace(/(다$)|(다(?=\.))|(다(?= ))|(다(?=!))|(다(?=\?))/gm, '다냥')
    //     .replace(/(야(?=\?))|(야$)|(야(?= ))/gm, '냥');
  }
}

extension NullableStringExtensions on String? {
  Color? get color {
    final colorString = this;
    if (colorString == null) {
      return const Color(0xFFFF0000);
    }

    if (!RegExp(r'^[0-9a-fA-F]+?$').hasMatch(colorString)) {
      return null;
    }

    final String htmlColor;
    if (colorString.length == 3) {
      htmlColor =
          "FF${colorString.substring(0, 1)}${colorString.substring(0, 1)}${colorString.substring(1, 2)}${colorString.substring(1, 2)}${colorString.substring(2, 3)}${colorString.substring(2, 3)}";
    } else if (colorString.length == 4) {
      htmlColor =
          "${colorString.substring(3, 4)}${colorString.substring(3, 4)}${colorString.substring(0, 1)}${colorString.substring(0, 1)}${colorString.substring(1, 2)}${colorString.substring(1, 2)}${colorString.substring(2, 3)}${colorString.substring(2, 3)}";
    } else if (colorString.length == 6) {
      htmlColor = "FF$colorString";
    } /*
      じつは8桁のカラーコードには対応してない
      else if (colorString.length == 8) {
      htmlColor = colorString;
    } */
    else {
      return null;
    }
    final intValue = int.tryParse(htmlColor, radix: 16);
    if (intValue == null) return null;
    return Color(intValue);
  }
}
