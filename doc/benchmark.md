# mfm_renderer ベンチマーク

計測の**手順と生の数値**を置く場所。何をなぜ直したかは
[performance-improvement.md](./performance-improvement.md) を参照。

## 手順

```sh
flutter test test/benchmark/mfm_benchmark_test.dart   # 数値を取る
flutter test test/golden/mfm_golden_test.dart         # 描画が変わっていないか確認
```

- 絶対値はマシン依存。**必ず同一マシン・同一 Flutter バージョンで改修前後を比較**する。
- 改修前の数値を取り直すには `git stash push -- lib` で実装だけ戻す（テストは残す）。
- **ばらつきが大きい**（同一条件でも 2 倍近い外れ値が出ることがある）。掲載値は
  **5 回実行の中央値**で、min-max も併記している。有意と判断するなら中央値で
  2 割以上を目安にし、1 割台の差はノイズと区別できないものとして扱う。

### 各列の意味

| 列 | 内容 |
| --- | --- |
| `parse` | `MfmParser().parse` 単体のコスト |
| `first_build` | 初回 `pumpWidget`（パース + スパンツリー構築 + レイアウト） |
| `rebuild` | 再ビルド 1 回あたりの `pumpWidget` 時間 |

`rebuild` は「テキストは同一、builder クロージャだけ毎回新しい」条件で測っている。
これは miria の `MfmText` の実使用条件（毎ビルドで新しいクロージャを渡すため
`Mfm.updateShouldNotify` が常に true）の再現。

計測環境: Flutter 3.44.6 / linux / `flutter test`（JIT・デバッグビルド。
リリースビルドの AOT では絶対値はこれより小さくなるが、比率の傾向は変わらない）

## 数値 (単位 us, 5 回実行の中央値)

ベース: `origin/main` (68b55b9)

### rebuild

| corpus | before | after | 変化 | before min-max | after min-max |
| --- | --- | --- | --- | --- | --- |
| plain_long | 25948 | 9643 | **-63%** | 24318–28326 | 9061–18163 |
| link_heavy | 27987 | 15769 | **-44%** | 27046–41237 | 14985–17820 |
| emoji_heavy | 37891 | 28390 | **-25%** | 36555–41166 | 26488–33820 |
| block_mixed | 17793 | 14719 | -17% | 17253–19093 | 12978–21409 |
| fn_nested | 36470 | 31606 | -13% | 34857–44680 | 26920–39184 |

`block_mixed` と `fn_nested` の 1 割台はばらつきと重なるので、**確実に効いていると
言えるのは上の 3 つ**。この 2 つはパース以外（入れ子 `Text.rich` のレイアウト）が
支配的で、そこは今回手を付けていないため妥当な結果。

### parse / first_build（参考, before の中央値）

| corpus | parse | first_build |
| --- | --- | --- |
| plain_long | 15346 | 539909 |
| emoji_heavy | 11826 | 216373 |
| link_heavy | 10156 | 102936 |
| fn_nested | 6125 | 182533 |
| block_mixed | 5891 | 55525 |

`first_build` はばらつきの範囲内で有意差なし（初回は必ずパースするので当然）。

## コーパス

`test/benchmark/mfm_corpus.dart`。ゴールデンテストと共用しているので、
変更するとベースライン値とゴールデン画像の両方が無効になる。

| corpus | 狙い |
| --- | --- |
| `plain_long` | プレーン長文。パースとテキストシェーピングの素の重さ |
| `emoji_heavy` | カスタム絵文字・Unicode 絵文字が多い。`WidgetSpan` 大量 |
| `link_heavy` | mention / hashtag / URL が多い。`tight` と recognizer 生成 |
| `fn_nested` | `$[fn]` のネストが深い。`MfmFnSpan` と入れ子 `Text.rich` |
| `block_mixed` | コードブロック・引用・中央寄せの混在 |
