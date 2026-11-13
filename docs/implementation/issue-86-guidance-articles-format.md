# #86 同梱の案内原稿ファイル（v1）

- 関係: [E6-6](../decisions/E6-6-guidance-content-source.md)（#49）、#86、#51〜#54
- 置き場所: `apps/nexus-ios/Nexus/Resources/Guidance/GuidanceArticles.json`（1ファイル）
- 読む実装: `GuidanceClient.bundled` / `BundledGuidanceCatalog`（`apps/nexus-ios/Nexus/Features/Guidance/Data/`）
- 現状: **記事は0件**。原稿の担い手（E6-6 §5 U-1）が決まるまで、仮の原稿・Figma の仮の情報は入れない。0件のときは案内タブに「案内の原稿はまだありません」と出る。

## 形式を JSON にした理由

| 案 | 判断 |
|---|---|
| **JSON 1ファイル（採用）** | Swift 標準の `JSONDecoder` だけで読め、ライブラリを足さない。E6-6「案B へ移るとき」の E2-5 bundle（JSON）へ項目をそのまま写せる。検証規則を Swift の試験で固定できる |
| Markdown + front matter | 本文は書きやすいが、iOS 標準に YAML の読み取りが無く、ライブラリ追加か自前の解析器が要る。見出し・段落のほか関連地点・FAQ・交通手段などの構造を Markdown の書き方の約束で表すことになり、bundle への写しも別途変換が要る |
| 記事ごとに JSON を分ける | 差分は読みやすくなるが、記事の並び順を別に持つ必要がある。記事数が少ない v1.0 では1ファイルで足りる |

## 形

```json
{
  "schemaVersion": 1,
  "articles": [
    {
      "id": "記事ID（大文字・小文字を保持。表示名から作らない）",
      "kind": "standard | help | helpHealth | access | faq",
      "navigationTitle": "ナビゲーションバーの短い表題",
      "title": "本文先頭の大見出し",
      "subtitle": "任意",
      "highlight": { "tone": "informational | caution", "systemImageName": "SF Symbols 名", "title": "…", "body": "…" },
      "sections": [ { "id": "記事内で一意", "heading": "任意", "paragraphs": ["…"] } ],
      "relatedSpots": [ { "canonicalSpotId": "確定した canonical ID", "displayName": "…", "supplementaryText": "任意" } ],
      "accessSegments": [ { "mode": "train | bus | car", "sections": [ … ], "relatedSpots": [ … ] } ],
      "faqItems": [ { "id": "…", "category": "任意", "question": "…", "answerParagraphs": ["…"] } ],
      "source": "元にした資料の名前と日付、または原稿の提供元",
      "confirmation": { "confirmedOn": "YYYY-MM-DD", "confirmer": "確認した人（役割名でよい）" },
      "homeShortcut": "任意。reception | help | access"
    }
  ]
}
```

`highlight` は `.help` / `.helpHealth`、`accessSegments` は `.access`、`faqItems` は `.faq` で使う。

`homeShortcut` は Home の「案内」ショートカット（[Home v1.0 下書き](../design/home-v1.0-draft.md) B）から開く記事に付ける。`reception`＝受付、`help`＝困ったとき、`access`＝アクセス。付いた記事があるショートカットだけが Home に出る。記事IDをコードに書かないための印で、1つのショートカットは1記事にだけ付けられる（重複・未知の値は公開条件違反としてファイル全体を読み込まない）。

## 公開条件（満たさなければ読み込まない）

次のどれか1つでも欠けた記事があれば、**ファイル全体を読み込まず**、案内タブは失敗の表示になる。欠けた記事だけを落とすと、目次から消えたことに気付けないため。

- `id`（重複不可）・`kind`・`navigationTitle`・`title`
- `source`・`confirmation.confirmedOn`（実在する日付）・`confirmation.confirmer`（E6-6 §4）
- 本文：`standard` / `help` / `helpHealth` は `sections`、`access` は `accessSegments`、`faq` は `faqItems` が1つ以上
- 記事内の重複なし：`sections` の `id`（同じ並びの中）、`accessSegments` の `mode`（交通手段ごとに1つ）、`faqItems` の `id`
- `relatedSpots` の `canonicalSpotId` と `displayName`。確定していない地点は書かない（無反応のボタンを出さない）

同梱ファイルは `BundledGuidanceCatalogTests.testShippedGuidanceFileIsPublishable` が CI で検証する。原稿を足す PR で欠けがあれば試験が落ち、どの記事の何が欠けたかが出る。

## 書かないもの

- 開催回ごとの日時・受付時間（E6-6 §2。Studio のイベント公開側に置く）
- 電話番号・公式リンク（#86「確認済みのみ表示」。所有者確認の記録方法が決まってから v2 で足す）
- 未確定の地点、Figma の仮の駅名・運行間隔（E6-6 §5）

## 今はまだ決めていないこと

- 正式な目次と分類（#86、P09）。現在は「困ったとき」（`help` / `helpHealth`）を上に、それ以外をファイル順に「案内一覧」として並べるだけ。目次の形が決まったら `schemaVersion` を上げて目次を足す。
- 関連地点の canonical ID が公開 bundle に実在するかの照合。今は空でないことだけを確かめる。
