# Home v1.0 デザイン下書き（A 開催日カード + B 案内ショートカット + C すべてのイベント）

- 状態: **ラフ（下書き）**。オーナーと対話しながら決めた並びと形。見た目の細部（色・角丸・アイコン）は Figma 担当が仕上げる。
- 作成: 2026-11-13
- 前提: [E2-5 改訂1 イベント配信](../decisions/E2-5-r1-event-delivery.md)、[E6-6 案内原稿の置き場所](../decisions/E6-6-guidance-content-source.md)、[デザインルール](../design-rules.md)
- お知らせは v1.0 では出さない（EV-D2）。この下書きにも入れていない。
- 画面の文言・日付・イベント名・カテゴリ・会場・中止理由は **すべてサンプル**。公式の情報ではない。

## 1. Figma のフレーム

ファイル: `WJqC7X5TuTvqTPnn40JIrV`、作業ページ「06｜Home v1.0｜旧版から寄せる作業｜2026-11」

| フレーム | 内容 | リンク |
|---|---|---|
| Step1 | 旧版 Home（`2316:1313`）を複製し、今のアプリに寄せたもの。マイク・現在地から案内・混雑状況・お知らせを外した | [2789:1513](https://www.figma.com/design/WJqC7X5TuTvqTPnn40JIrV/?node-id=2789-1513) |
| Step2 | Step1 + A 開催日カード | [2790:1532](https://www.figma.com/design/WJqC7X5TuTvqTPnn40JIrV/?node-id=2790-1532) |
| **Step3（Home の確定案）** | Step2 + B 案内ショートカット | [2791:1602](https://www.figma.com/design/WJqC7X5TuTvqTPnn40JIrV/?node-id=2791-1602) |
| A の状態一覧 | 開催中・開催前（複数日）・終了・中止 | [2790:1744](https://www.figma.com/design/WJqC7X5TuTvqTPnn40JIrV/?node-id=2790-1744) |
| B の状態一覧 | 記事3件・一部のみ・0件 | [2791:1832](https://www.figma.com/design/WJqC7X5TuTvqTPnn40JIrV/?node-id=2791-1832) |
| C 一覧（すべて・中止の枠を含む） | Home の「すべて見る」から開く | [2795:1653](https://www.figma.com/design/WJqC7X5TuTvqTPnn40JIrV/?node-id=2795-1653) |
| C 一覧（カテゴリで絞り込み） | カテゴリA を選んだ状態 | [2795:1713](https://www.figma.com/design/WJqC7X5TuTvqTPnn40JIrV/?node-id=2795-1713) |

部品（ページ06 にある下書き用コンポーネント）:

- `HomeDraft/DayOverview`（State = 開催中 / 開催前（複数日）/ 終了 / 中止）
- `HomeDraft/GuidanceShortcut`
- `EventListDraft/CategoryChip`（Selected = true / false）
- `EventListDraft/SlotRow`（State = 通常 / 中止）

色・余白・文字は既存の変数 `Nexus/v1.0/Review-20260908/Semantic/*` とテキストスタイル `Nexus/HomePrep/iOS/*` を使っている。

### HIG 修正版（ページ07「07｜Home v1.0｜HIG修正版｜2026-11」）

ページ06 の確定案をコピーし、Apple の HIG（iOS・マテリアル・タブバー・レイアウト・ツールバー・ボタン）と Liquid Glass の概要に合わせて直した版。元のフレームは変更していない。**実装はこの版を基準にする。**

| フレーム | リンク |
|---|---|
| Home（当日・開催中） | [2798:1513](https://www.figma.com/design/WJqC7X5TuTvqTPnn40JIrV/?node-id=2798-1513) |
| 一覧（すべて・中止の枠を含む） | [2799:1665](https://www.figma.com/design/WJqC7X5TuTvqTPnn40JIrV/?node-id=2799-1665) |
| 一覧（カテゴリで絞り込み） | [2799:1728](https://www.figma.com/design/WJqC7X5TuTvqTPnn40JIrV/?node-id=2799-1728) |
| 一覧（スクロール後：見出しが上部に縮む） | [2799:1785](https://www.figma.com/design/WJqC7X5TuTvqTPnn40JIrV/?node-id=2799-1785) |

主な変更: フォントを SF Pro に統一、本文の最小 11pt、ボタンの高さ 44 以上、旧版の会場名・イベント名をサンプル表記に、旧版の固定配置の部品を HomePrep の部品に置き換え、一覧の戻るボタンを標準の Liquid Glass の形に。経路ボタンは「マップで見る」にし、マップタブと同じピンのアイコンを付けた（押すとマップタブへ移って経路を出すことが分かるように）。一覧ではこのボタンをタイトルの下に置く。部品は `HomeHIG/EventCard`・`EventListHIG/SlotRow`（ページ07）。Liquid Glass はタブバーと戻るボタンだけに使い、中身には使っていない。

ページ05「Home v1.0 draft（A+B+C）｜ラフ」は、対話の前に先に作った比較用。確定案ではない（ボトムバー固定の修正も入れていない）。

### Home の並び（Step3）

1. ヘッダー（Nexus / 今日はどこへ行きますか？）
2. 検索
3. **A. 開催日カード**
4. 次のイベント
5. **B. 案内**（受付・困ったとき・アクセス）
6. この後のイベント（横スクロールのカード、最大10件）＋「すべて見る」→ **C**

フレームは 852 の高さで中を縦スクロールにし、ステータスバーとボトムバーは固定にしてある（スクロールしても表示されたまま）。

## 2. どのデータで何を出すか

### A. 開催日カード — `occurrences[].days[]`

| 表示 | データ |
|---|---|
| 「8月1日（日）10:00〜15:00」 | `date`、`public_start`、`public_end` |
| 状態バッジ（開催前 / 開催中 / 終了 / 中止） | `status` と端末の現在時刻 |
| 補足の1行（「15:00まで公開中です」「開催まであと3日」など） | 同上 |
| 中止の理由 | `cancel_note` |
| 「ほかの開催日」 | 同じ開催回のほかの `days[]` |

状態の決め方:

- **中止**: `status == "cancelled"`。ほかの条件より優先する。
- **開催前**: 今日がその日より前、または当日で `public_start` より前。
- **開催中**: 当日で `public_start`〜`public_end` の間。
- **終了**: 当日で `public_end` を過ぎた後。

どの日を出すか: 今日の開催日があればその日。なければ、これから来る一番近い日。それもなければ、最後の開催日（終了）。

### B. 案内ショートカット — `Resources/Guidance/GuidanceArticles.json`

- 受付・困ったとき・アクセスの記事が **あるものだけ** 出す。タップするとその記事の詳細を開く（案内タブと同じ記事画面）。
- 今の JSON は `articles: []` なので、実装しても記事が入るまでは何も出ない。

### C. すべてのイベント — `events[]` と `events[].slots[]`、`categories[]`

| 表示 | データ |
|---|---|
| 1行 = 1つの枠 | `events[].slots[]`（公開済みのものすべて。時間で絞らない） |
| 並び順 | 日付 → 開始時刻の早い順 |
| 日ごとの見出し・「今日」バッジ | `slots[].date` |
| 開始・終了の時刻 | `start` / `end` |
| 「終日」「随時参加」 | `time_mode == allDay` / `participation == anytime`（Home と同じ `HomeEventProjection.modeText`） |
| カテゴリ名・絞り込みボタン | `events[].category_id` → `categories[].name` |
| 会場 | 枠の地点（Home カードと同じ解決方法） |
| 中止（「中止：理由」、経路ボタンなし） | 枠の `status`、または開催日の `status` が `cancelled`（EV-09）。理由は `cancel_note` |

行をタップするとイベント詳細（PR #164 の `eventDetails`）を開く。経路ボタンは `route(destinationSpotID:)`。

## 3. 空の状態と端のケース

| ケース | 表示 |
|---|---|
| 開催日が0件 | A のカードごと出さない |
| 開催日が2日以上 | 「ほかの開催日」を出す（Figma は開催前の例だけ） |
| 開催日の `public_start` / `public_end` が null | 日付だけ出す（Figma 未作成） |
| 開催日が中止 | A は中止の表示。その日の枠は Home のカード・一覧とも「中止」で残す。次のイベントには出さない |
| 最後の開催日の公開が終わった後 | A は「終了」。この後のイベントは空になる（Home の空の表示は Figma 未作成。今のアプリの `HomeStatusView` のままにするか要相談） |
| 案内記事が1件もない | B は見出しごと出さない |
| 案内記事が一部だけある | あるものだけを並べ、幅を分け合う |
| 一覧で、選んだカテゴリの枠が0件 | 「このカテゴリのイベントはありません」などの空の表示（Figma 未作成） |
| カテゴリなし（`category_id == null`）の枠 | 「すべて」でだけ出す。カテゴリ名の行は出さない |
| 保存版の表示中（オフライン） | 今の Home と同じく保存版のバナーを上に出す（Figma 未作成） |

## 4. Figma 担当への質問

1. 開催日カードの見出し「オープンキャンパス開催日」は、この文言でよいか。
2. 「開催中」の青い塗りのバッジは強すぎないか。
3. 案内ショートカットのアイコンは仮のもの（受付 = person.fill、困ったとき = info.circle、アクセス = figure.walk）。困ったときは questionmark.circle などに変えるか。
4. （ページ07 で対応済み）経路ボタンは Home・一覧とも「マップで見る」＋マップタブのピンのアイコンに揃えた。文言とアイコンの最終確認。
5. カテゴリの見た目が揃っていない。Home のカードは旧版のままの色つきピル、一覧は青い文字だけ。どちらに揃えるか。
6. Step1 で残した旧版の見た目（次のイベントの縦線が青。アプリはオレンジ `eventAccent`）をどちらに揃えるか。
7. Figma 未作成の状態（終了後の Home の空表示、一覧の0件、保存版バナー）を作るか。
8. 案内の正式な原稿と目次（E6-6 の U-1〜U-3）が決まったら、ショートカットの3つを入れ替える必要があるか。

## 5. あとで必要になるコードの変更（この下書きでは実装しない）

- **A**
  - 開催日の射影（`days[]` → 状態・表示文字列）を作り、`HomeSnapshot` に開催日カードの項目を足す。
  - `HomeDayOverviewView` を新しく作り、`HomeView` の検索の下に置く。
  - 状態の判定は時刻で変わるので、今の Home と同じく境界ごとに読み直す（#48）。
  - テストを足す: 0件・複数日・中止・null の公開時間・各状態の境界。
- **B**
  - `BundledGuidanceCatalog` から受付・困ったとき・アクセスの記事があるかを Home に渡す。
  - 新しい遷移の要求（例: `AppRouteRequest.guidanceArticle(id)`）を作り、案内タブの記事詳細を開く。
  - 記事数を0件に固定しているテストは、正式な原稿を入れる PR で外す（PR #163 の申し送り）。
- **C**
  - `.allEvents` は今は `NotProvidedView(topic: .eventList)`。一覧の画面・Store・射影（時間で絞らない、日ごとにまとめる）を新しく作り、`AppRouteCoordinator` から開く。
  - カテゴリの絞り込みは画面の中の状態として持つ。
  - 中止の判定と「終日」「随時参加」の文字列は Home と共通の関数（`HomeEventProjection.modeText` / `monthDayText`）を使う。
- **共通**
  - Home のカードと一覧の行は「経路」ボタンの文言とカテゴリの見せ方を揃える（質問4・5 の答えしだい）。
