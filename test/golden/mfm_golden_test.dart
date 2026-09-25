// 描画結果の同一性を守るためのゴールデンテスト。
//
// 高速化の改修前に生成し、改修後に差分が出ないことを確認する。
// 画像の更新: flutter test --update-goldens test/golden/mfm_golden_test.dart
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mfm/mfm.dart';

import '../benchmark/mfm_corpus.dart';

void main() {
  for (final entry in mfmCorpus.entries) {
    testWidgets("${entry.key} の描画が変わらない", (tester) async {
      tester.view.physicalSize = const Size(600, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            backgroundColor: Colors.white,
            body: SingleChildScrollView(
              child: Mfm(
                mfmText: entry.value,
                // アニメーションは非決定的なので止める。
                isUseAnimation: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile("goldens/${entry.key}.png"),
      );
    });
  }
}
