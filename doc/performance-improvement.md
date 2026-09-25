# レンダリングコストの削減 (2026-09)

> PR 本文にそのまま使える形でまとめている。数値の取り方と生データは
> [benchmark.md](./benchmark.md) を参照。

## 概要

`Mfm` ウィジェットの**再ビルドコストを削減**した（プレーン長文で -63%、
mention/URL の多いノートで -44%、絵文字の多いノートで -25%）。
描画結果は変えていない（ゴールデンテストで担保）。

miria のタイムラインは 1 ノートごとに `Mfm` を構築するため、スクロール中は
再ビルドが連続して起きる。そこで支配的だったのが「**再ビルドごとに MFM 全文を
再パースしている**」という実装漏れで、これを含む 5 点を修正した。

## 背景

`miria/lib/view/common/misskey_notes/mfm_text.dart` の `MfmText` は、ビルドごとに
新しい `emojiBuilder` などのクロージャを `Mfm` に渡す。そのため
`Mfm.updateShouldNotify` が常に true を返し、スクロール・テーマ変更・
アニメーション由来の再ビルドのたびにスパンツリーが丸ごと作り直される。

この「再ビルドが頻繁に起きる」前提のもとで、本来やらなくていい仕事が
どれだけ混ざっているかを測ったのが今回の出発点。

## 結果

`rebuild` = 「テキストは同一、builder クロージャだけ毎回新しい」条件での
再ビルド 1 回あたりの時間。**5 回実行の中央値**、単位 us。ベースは `origin/main` (68b55b9)。

| corpus | before | after | 変化 | before min-max | after min-max |
| --- | --- | --- | --- | --- | --- |
| plain_long | 25948 | 9643 | **-63%** | 24318–28326 | 9061–18163 |
| link_heavy | 27987 | 15769 | **-44%** | 27046–41237 | 14985–17820 |
| emoji_heavy | 37891 | 28390 | **-25%** | 36555–41166 | 26488–33820 |
| block_mixed | 17793 | 14719 | -17% | 17253–19093 | 12978–21409 |
| fn_nested | 36470 | 31606 | -13% | 34857–44680 | 26920–39184 |

`block_mixed` と `fn_nested` の 1 割台はばらつきと重なるため、**確実に効いていると
言えるのは上の 3 つ**。この 2 つは入れ子 `Text.rich` のレイアウトが支配的で、
そこは今回のスコープ外（[残っている改善余地](#残っている改善余地)）。

初回ビルド (`first_build`) はばらつきの範囲内で有意差なし。初回は必ずパースするため。

計測環境: Flutter 3.44.6 / linux / `flutter test`（JIT・デバッグビルド）。
絶対値はマシン依存なので、比率のほうを見てほしい。生データと手順は
[benchmark.md](./benchmark.md)。

## 変更内容

### 1. パース結果のキャッシュ — 効果の大半はこれ

`lib/src/mfm_parent_widget.dart`

`MfmParentWidgetState.nodes` フィールドは宣言されていたが、**どこからも代入されて
いなかった**。そのため `nodes == null` が永久に真で、`build` ごとに

```dart
actualNode = const MfmParser().parse(Mfm.of(context).mfmText!);
```

が実行されていた。`plain_long` では再ビルド 26ms のうち 16ms、**6 割強がパース**。

パース結果とパース元（テキストと `defaultHost`）を保持し、どちらかが変わったときだけ
パースし直すようにした。`mfmNode` を直接渡された場合の優先順位は従来どおり。

### 2. `Mfm.of(context)` のホイスト

`lib/src/mfm_inline_span.dart`, `lib/src/mfm_fn_span.dart`, `lib/src/mfm_parent_widget.dart`

`Mfm.of` は `dependOnInheritedWidgetOfExactType` = ツリー遡上 + 依存登録を伴うが、
スパン構築のなかでノード 1 個ごとに何度も呼ばれていた（`isNyaize`、各 builder、
各 style で `mfm_fn_span.dart` だけで 20 箇所）。`buildChildren` の先頭で 1 回引いて
ローカル変数を使う形に統一した。依存登録は 1 回残るのでテーマ変更時の再ビルド挙動は不変。

### 3. `TapGestureRecognizer` のプール化（リーク修正も兼ねる）

`lib/src/mfm_gesture_recognizer_pool.dart`（新規）, `lib/src/mfm_element_widget.dart`

mention / hashtag / URL のスパンは再ビルドごとに `TapGestureRecognizer()` を
new していて、しかも**誰も `dispose()` していなかった**（リーク）。

スパンツリーは同じノード列から同じ順序で決定的に構築されるので、構築順のインデックスで
recognizer を貸し出して `onTap` だけ差し替えるプールを導入した。プールは
`MfmElementWidget` が所有し、`dispose` でまとめて破棄する。

### 4. `findChildrenNewLine` の 1 回評価

`lib/src/mfm_fn_span.dart`

`resolveAlignment` が `MfmFn` ごとに毎回部分木を歩いていたので、`late final` で
1 度だけ判定するようにした。

### 5. `String.tight` の高速パス + メモ化

`lib/src/extension/string_extension.dart`

`tight` は grapheme cluster の境界すべてに ZWSP を挟む処理で、mention / hashtag /
URL ごとに毎回走る。元の実装は `Characters` による grapheme 分割を通していた。

- 表示可能 ASCII (`0x20`–`0x7E`) のみの文字列は、1 文字 = 1 cluster が保証できるので
  `characters` を通さず直接組み立てる。`\r\n` のように複数コードユニットで 1 cluster に
  なる組み合わせを避けるため制御文字は除外し、従来経路にフォールバックする。
- 結果を上限 512 件のキャッシュに載せる。

元実装との出力一致は `test/string_extension_test.dart` で、結合文字・ZWJ 絵文字・
地域表示記号・CRLF・キャッシュ上限超過を含めて検証している。

## テスト

### 追加

| ファイル | 役割 |
| --- | --- |
| `test/benchmark/mfm_corpus.dart` | ベンチとゴールデン共用の MFM コーパス 5 種 |
| `test/benchmark/mfm_benchmark_test.dart` | パース単体 / 初回ビルド / 再ビルド 50 回の計測 |
| `test/golden/mfm_golden_test.dart` | 描画結果の同一性（`isUseAnimation: false` で決定化） |
| `test/string_extension_test.dart` | `tight` が元実装と完全一致すること |
| `dart_test.yaml` | `benchmark` タグの宣言（CI では skip 可） |

### 確認手順

```sh
flutter analyze
flutter test                                        # 全件パス
flutter test test/golden/mfm_golden_test.dart        # 全コーパスで差分なし
flutter test test/benchmark/mfm_benchmark_test.dart  # 数値を取る
```

ゴールデン画像を更新する必要が出た場合は `flutter test --update-goldens`。
差分が出たら**描画が変わっている**ので、原因を確認してから更新すること。

miria 側から `path:` 依存で参照して実機タイムラインも目視確認する（miria のコードは
今回変更していない）。

## 残っている改善余地

今回は「描画結果を完全に維持する」方針だったため、以下は手を付けていない。

- **入れ子 `Text.rich` / `WidgetSpan` の統合** — `$[fn]`・引用・中央寄せごとに独立した
  `RenderParagraph` ができる。`fn_nested` / `emoji_heavy` に残るコストは主にここで、
  単一パラグラフに統合できれば効果は大きい。ただし折り返しとベースラインの見た目が
  変わりうるので、別途ゴールデンの張り替えを伴う判断が必要。
- **miria 側 `MfmText` のクロージャ安定化** — `Mfm.updateShouldNotify` が常に true に
  なる原因。ここを直せばスパンツリーの再構築自体を丸ごと省ける。mfm_renderer 側の
  修正とは独立して効く。
- **既存バグ**: `MfmFnSpan.findChildrenNewLine` は最初の非テキスト子で `return` して
  しまい、兄弟ノードを走査しない。挙動が変わるため今回は温存した（別 issue 向き）。
