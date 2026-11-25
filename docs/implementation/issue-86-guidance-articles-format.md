# #86 同梱の案内原稿ファイル（v1）

- 関係: [E6-6](../decisions/E6-6-guidance-content-source.md)（#49）、#86、#51〜#54
- 置き場所: `apps/nexus-ios/Nexus/Resources/Guidance/GuidanceArticles.json`（1ファイル）
- 読む実装: `GuidanceClient.bundled` / `BundledGuidanceCatalog`（`apps/nexus-ios/Nexus/Features/Guidance/Data/`）
- 現状: 2026-11-25 に原稿の確認体制が確定した（E6-6 §5 U-1）。**同梱ファイルの記事は0件**。オーナーが公式資料と照合した正式原稿を後続 PR で投入する。案内タブには3分類の目次を表示し、原稿がない項目には「準備中」と出す。「このアプリについて」はアプリ側で持つ。

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
      "navigationTitle": "記事の短い表題（既存の原稿形式）",
      "title": "本文先頭の大見出し",
      "subtitle": "任意",
      "highlight": { "tone": "informational | caution", "systemImageName": "SF Symbols 名", "title": "…", "body": "…" },
      "sections": [ { "id": "記事内で一意", "heading": "任意", "paragraphs": ["…"] } ],
      "relatedSpots": [ { "canonicalSpotId": "確定した canonical ID", "displayName": "…", "supplementaryText": "任意" } ],
      "officialContacts": [ { "id": "記事内で一意", "kind": "phone | web", "label": "表示名", "url": "tel:... または https://..." } ],
      "accessSegments": [ { "mode": "train | bus | car", "sections": [ { "id": "t1", "paragraphs": ["…"] } ], "relatedSpots": [] } ],
      "faqItems": [ { "id": "…", "category": "任意", "question": "…", "answerParagraphs": ["…"] } ],
      "source": "元にした資料の名前と日付、または原稿の提供元",
      "confirmation": { "confirmedOn": "YYYY-MM-DD", "confirmer": "確認した人（役割名でよい）" },
      "homeShortcut": "任意。reception | help | access"
    }
  ]
}
```

`highlight` は `.help` / `.helpHealth`、`accessSegments` は `.access`、`faqItems` は `.faq` で使う。

`officialContacts` は任意。公式 HP に掲載された公式 URL・代表電話をオーナーが照合したうえで記載する。省略時は連絡先0件として従来の原稿を読めるため、`schemaVersion` は `1` のままとする。

`homeShortcut` は Home の「案内」ショートカット（[Home v1.0 下書き](../design/home-v1.0-draft.md) B）から開く記事に付ける。`reception`＝受付、`help`＝困ったとき、`access`＝アクセス。付いた記事があるショートカットだけが Home に出る。記事IDをコードに書かないための印で、1つのショートカットは1記事にだけ付けられる（重複・未知の値は公開条件違反としてファイル全体を読み込まない）。

## 公開条件（満たさなければ読み込まない）

次のどれか1つでも欠けた記事があれば、**ファイル全体を読み込まず**、案内タブは失敗の表示になる。欠けた記事だけを落とすと、目次から消えたことに気付けないため。

- `id`（重複不可）・`kind`・`navigationTitle`・`title`
- `source`・`confirmation.confirmedOn`（実在する日付）・`confirmation.confirmer`（E6-6 §4）
- 本文：`standard` / `help` / `helpHealth` は `sections`、`access` は `accessSegments`、`faq` は `faqItems` が1つ以上
- 記事内の重複なし：`sections` の `id`（同じ並びの中）、`accessSegments` の `mode`（交通手段ごとに1つ）、`faqItems` の `id`
- `relatedSpots` の `canonicalSpotId` と `displayName`。確定していない地点は書かない（無反応のボタンを出さない）
- `officialContacts` の各連絡先には、記事内で一意の `id`、`kind`（`phone` / `web`）、表示名 `label`、対応する `url` が必要。`id`・`label`・`url` は空文字や空白だけの値を受け付けない。
  - `phone` は `tel:` に続く電話番号に ASCII 数字を1文字以上含み、使える文字は `0–9`、`+`、`-`、`(`、`)` に限る（例 `tel:0120-87-8622`）。
  - `web` は `https:` スキームでホスト名が必要（例 `https://www.jaa-tech.jp/`）。

同梱ファイルは `BundledGuidanceCatalogTests.testShippedGuidanceFileIsPublishable` が CI で検証する。原稿を足す PR で欠けがあれば試験が落ち、どの記事の何が欠けたかが出る。

## 書かないもの

- 開催回固有の日時・受付時間・受付場所・駐車場の利用可否。Studio のイベント公開で扱う（E6-6 §2）。
- 年度で変わる実績数値・料金、教員の個人名、交通機関の便数・時刻表。詳細は `officialContacts` に記載した確認済みの公式 URL へ案内する。
- 写真（v1.0 対象外）。
- 未確認の推測情報。未確定の地点や Figma の仮の駅名・運行間隔も含む。

## 3分類の目次（P09）

| 分類 | 項目順と原稿の標準 ID |
|---|---|
| 困ったとき・緊急 | 気分が悪くなったら `health`、困ったとき `help` |
| 当日のご案内 | 受付のご案内 `reception`、交通アクセス `access`、施設利用・学食 `facility`、注意事項・マナー `manners` |
| 学校を知る | 学科紹介 `department`、学校生活 `schoolLife`、学生寮 `dormitory`、よくある質問（FAQ） `faq`、このアプリについて `about` |

`homeShortcut` の印がある原稿は、それと同じ項目から既存の記事 ID で開く。印がないときは標準 ID で割り当てる。標準 ID に一致しない場合でも、`helpHealth`・`help`・`access`・`faq` は種類に対応する項目に割り当てられる。複数の原稿が同じ項目に該当する場合は、印、標準 ID、種類の順で優先する。同じ優先度ではファイルの先頭の原稿を使う。

`source` と `confirmation` は公開条件と原稿の品質管理に使い、画面には表示しない（U-3）。「このアプリについて」の国土地理院出典欄は [K-3 §4](../decisions/E1-4-r4-k3-gsi-procedure.md#4-出典の書き方と置き場所) に従い、承認書の番号と正式文言を確認後に差し替える。

## 今はまだ決めていないこと

- 関連地点の canonical ID が公開 bundle に実在するかの照合。今は空でないことだけを確かめる。
