// mfm_renderer のレンダリングコストを測るベンチマーク。
//
// 実行:
//   flutter test test/benchmark/mfm_benchmark_test.dart
//
// 結果は stdout に表で出るので doc/benchmark.md に転記して比較する。
// 絶対値はマシン依存なので、必ず同一マシンで改修前後を比較すること。
@Tags(["benchmark"])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mfm/mfm.dart';
import 'package:mfm_parser/mfm_parser.dart';

import 'mfm_corpus.dart';

/// 再ビルド回数。miria のタイムラインでのスクロール中の再ビルドを模す。
const _rebuildCount = 50;

/// 計測前に捨てるウォームアップ回数（JIT の暖機）。
const _warmupCount = 5;

/// miria の `MfmText` と同じく、ビルドごとに新しいクロージャを渡す。
/// これにより `Mfm.updateShouldNotify` が毎回 true になる実使用条件を再現する。
Widget _buildMfm(String text, int seed) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: Mfm(
          mfmText: text,
          isUseAnimation: false,
          // ignore: prefer_const_constructors, 意図的に毎回別インスタンスにする
          emojiBuilder: (context, name, style) => Text(":$name:", style: style),
          unicodeEmojiBuilder: (context, emoji, style) =>
              TextSpan(text: emoji, style: style),
          codeBlockBuilder: (context, code, lang) => Text(code),
          mentionTap: (userName, host, acct) {},
          hashtagTap: (hashtag) {},
          linkTap: (url) {},
          // seed を style に混ぜてしまうと描画自体が変わるので使わない。
          // 未使用警告避けのためだけに参照する。
          suffixSpan: seed < 0 ? const [TextSpan(text: "")] : const [],
        ),
      ),
    ),
  );
}

/// [body] を [count] 回まわしたときの 1 回あたりのマイクロ秒。
double _measure(int count, void Function(int i) body) {
  final sw = Stopwatch()..start();
  for (var i = 0; i < count; i++) {
    body(i);
  }
  sw.stop();
  return sw.elapsedMicroseconds / count;
}

void main() {
  final results = <String, Map<String, double>>{};

  group("MFM parse only", () {
    for (final entry in mfmCorpus.entries) {
      test("${entry.key} のパース単体コスト", () {
        const parser = MfmParser();
        for (var i = 0; i < _warmupCount; i++) {
          parser.parse(entry.value);
        }
        final us = _measure(20, (_) => parser.parse(entry.value));
        (results[entry.key] ??= {})["parse_us"] = us;
      });
    }
  });

  group("MFM widget", () {
    for (final entry in mfmCorpus.entries) {
      testWidgets("${entry.key} の初回ビルドと再ビルド", (tester) async {
        tester.view.physicalSize = const Size(1080, 4000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        // 初回ビルド（パース + スパンツリー構築 + レイアウト）
        final firstSw = Stopwatch()..start();
        await tester.pumpWidget(_buildMfm(entry.value, 0));
        firstSw.stop();
        (results[entry.key] ??= {})["first_build_us"] =
            firstSw.elapsedMicroseconds.toDouble();

        // ウォームアップ
        for (var i = 0; i < _warmupCount; i++) {
          await tester.pumpWidget(_buildMfm(entry.value, i + 1));
        }

        // 再ビルド: テキストは同一、クロージャだけ毎回新しい
        final sw = Stopwatch()..start();
        for (var i = 0; i < _rebuildCount; i++) {
          await tester.pumpWidget(_buildMfm(entry.value, i + 100));
        }
        sw.stop();
        results[entry.key]!["rebuild_us"] =
            sw.elapsedMicroseconds / _rebuildCount;
      });
    }
  });

  tearDownAll(() {
    final keys = mfmCorpus.keys.where(results.containsKey).toList();
    if (keys.isEmpty) return;
    // ignore: avoid_print
    print("\n=== mfm_renderer benchmark (us) ===");
    // ignore: avoid_print
    print("corpus          parse   first_build   rebuild   rebuild/parse");
    for (final key in keys) {
      final r = results[key]!;
      final parse = r["parse_us"];
      final rebuild = r["rebuild_us"];
      final ratio = (parse != null && parse > 0 && rebuild != null)
          ? (rebuild / parse).toStringAsFixed(1)
          : "-";
      // ignore: avoid_print
      print(
        "${key.padRight(15)} "
        "${(parse ?? 0).toStringAsFixed(0).padLeft(6)} "
        "${(r["first_build_us"] ?? 0).toStringAsFixed(0).padLeft(12)} "
        "${(rebuild ?? 0).toStringAsFixed(0).padLeft(9)} "
        "${ratio.padLeft(15)}",
      );
    }
    // ignore: avoid_print
    print(
      "\nrebuild が parse と同程度以上なら、再ビルドごとに再パースが起きている疑いが強い。",
    );
  });
}
