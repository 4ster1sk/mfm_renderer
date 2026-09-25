# mfm_renderer ベンチマーク

計測の**手順と生の数値**を置く場所。何をなぜ直したかは
[performance-improvement.md](./performance-improvement.md) を参照。

## 手順

```sh
flutter test test/benchmark/mfm_benchmark_test.dart   # 数値を取る
flutter test test/golden/mfm_golden_test.dart         # 描画が変わっていないか確認
```

- 絶対値はマシン依存。**必ず同一マシン・同一 Flutter バージョンで改修前後を比較**する。
- 改修前の数値を取り直すには `git checkout <base> -- lib` で実装だけ戻す（テストは残す）。
  戻すときは `git checkout HEAD -- lib`。
- **ばらつきが大きい**（同一条件でも 1.3 倍程度の外れ値が出ることがある）。掲載値は
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

ベース: upstream の main (39918d1)

### rebuild

| corpus | before | after | 変化 | before min-max | after min-max |
| --- | --- | --- | --- | --- | --- |
| plain_long | 23570 | 8716 | **-63%** | 23132–24511 | 8223–8963 |
| link_heavy | 26449 | 14690 | **-44%** | 25937–27987 | 14526–16178 |
| block_mixed | 18966 | 12782 | **-33%** | 17381–21369 | 11806–13528 |
| emoji_heavy | 36033 | 25336 | **-30%** | 35898–37263 | 24882–27047 |
| fn_nested | 34325 | 27600 | **-20%** | 33674–45708 | 27036–28925 |

`fn_nested` の before は 1 回だけ 45708 の外れ値が出ている（中央値は 34325）。
入れ子 `Text.rich` のレイアウトが支配的なこの 2 つ（`fn_nested` / `block_mixed`）は、
パース以外の比率が高いぶん改善幅も小さい。

### parse / first_build（参考, before の中央値）

| corpus | parse | first_build |
| --- | --- | --- |
| plain_long | 15257 | 494574 |
| emoji_heavy | 10413 | 187030 |
| link_heavy | 9328 | 101768 |
| fn_nested | 5727 | 153189 |
| block_mixed | 4877 | 52158 |

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
