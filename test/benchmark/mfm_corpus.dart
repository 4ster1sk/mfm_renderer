/// ベンチマーク／ゴールデンテストで共用する MFM コーパス。
///
/// miria のタイムラインに実際に流れてくるノートの傾向を模した 5 パターン。
/// 追加・変更するとゴールデン画像とベースライン値が無効になるので注意。
library;

const _plainParagraph =
    "きょうはいい天気だったので散歩に出かけました。公園の桜がもう咲きはじめていて、"
    "思わず立ち止まって見上げてしまいました。Spring is finally here, and the air "
    "smells completely different from last week.\n"
    "帰りにコンビニでアイスを買って食べたら、すこし寒かったです。";

/// プレーンな長文。パースとテキストシェーピングの素の重さを見る。
final String plainLongText = List.filled(8, _plainParagraph).join("\n\n");

/// カスタム絵文字・Unicode 絵文字が多いノート。WidgetSpan が大量に出る。
final String emojiHeavyText = List.generate(
  40,
  (i) => "たのしい :party_parrot: :blobcatnodding: 🎉🙌✨ 第$i回 :ablobcatcry:",
).join("\n");

/// mention / hashtag / URL が多いノート。`String.tight` と
/// `TapGestureRecognizer` の生成コストが支配的になる。
final String linkHeavyText = List.generate(
  30,
  (i) =>
      "@user$i@example$i.tld さんの投稿 #misskey #miria$i "
      "https://example$i.tld/notes/abcdefghijklmnop$i?query=%E3%83%86%E3%82%B9%E3%83%88",
).join("\n");

/// `$[fn]` のネストが深いノート。MfmFnSpan と入れ子 Text.rich の重さを見る。
final String fnNestedText = List.generate(
  12,
  (i) => "\$[x2 \$[fg.color=f00 \$[font.serif \$[border.radius=4 "
      "ネスト$i \$[scale.x=1.2,y=1.2 ふかい \$[position.x=0.1 ずれ]]]]]] "
      "\$[flip.h,v はんてん] \$[rotate.deg=15 かいてん] \$[ruby 東京 とうきょう]",
).join("\n");

/// コードブロック・引用・中央寄せなどブロック要素が混在するノート。
final String blockMixedText = List.generate(
  6,
  (i) => """
<center>みだし $i</center>

> 引用された文章がここにあります。
> ネストした引用も試します。
>> ふかい引用 $i

```dart
void main() {
  // サンプル $i
  print("hello, mfm");
}
```

`inline code $i` と **太字** と <small>ちいさい</small> と ~~打ち消し~~。
""",
).join("\n");

/// ベンチ／ゴールデン共用の対象一覧。
final Map<String, String> mfmCorpus = {
  "plain_long": plainLongText,
  "emoji_heavy": emojiHeavyText,
  "link_heavy": linkHeavyText,
  "fn_nested": fnNestedText,
  "block_mixed": blockMixedText,
};
