# Figma 反映依頼（2026-11）

- 作成: 2026-11-14（2026-11-15 更新：位置情報・Map・公開サイトの依頼 P-1〜W-1 を追加。#184〜#203 の分）
- 宛先: Figma 担当
- 目的: iOS を先に直した変更（EV-O3 の方針）を Figma に揃えてもらう。あわせて、デザイナーの回答が必要な質問を1か所にまとめる。
- 対象ファイル: `WJqC7X5TuTvqTPnn40JIrV`
  - ページ06「Home v1.0｜旧版から寄せる作業」: [Step3（Home の確定案）2791:1602](https://www.figma.com/design/WJqC7X5TuTvqTPnn40JIrV/?node-id=2791-1602)
  - ページ07「Home v1.0｜HIG修正版」（**実装の基準**）: [Home 2798:1513](https://www.figma.com/design/WJqC7X5TuTvqTPnn40JIrV/?node-id=2798-1513)
- 元にした資料: [home-v1.0-draft.md](home-v1.0-draft.md) §4、[E2-5 改訂1](../decisions/E2-5-r1-event-delivery.md) EV-O1・EV-O3、[E6-6](../decisions/E6-6-guidance-content-source.md) U-3、[design-rules.md](../design-rules.md)、各 PR の「Figma との差」
- 画面の文言・日付・イベント名などは、どれもサンプル。公式の情報ではない。

## 0. 前提（デザインルール）

- iOS は Nexus 全体のルールに従い、書いていない点は Apple HIG に従う。
- フォントは **SF Pro**（Figma でも SF Pro）。背景は `systemBackground` のまま（グラデーションにしない）。
- **ライトとダークの両方**に対応する。白・黒を直接置かず、Light / Dark の値を持つ Variables を使う。
- Material 3 風の **Elevation 3段階・State layer・Ripple** は iOS に入った（[#172](https://github.com/m0o9l0v3/NexusMobile/pull/172)）。Figma の部品にも、Elevation・押下（Pressed）状態・ダークの見た目が要る。

## 1. 優先度と記号

| 優先度 | 意味 |
|---|---|
| **P1** | アプリと Figma が明らかに違う、または回答がないと実装を決められない。最初に対応してほしい |
| **P2** | 見た目の細部の差。P1 の後で揃えてほしい |
| **P3** | 作るかどうかから相談したいもの・後でよいもの |

「質問」の欄が **要回答** の項目は、Figma を直す前にデザイナーの判断が必要。回答はこのファイルへのコメントか、オーナーへの返信で構わない。

## 2. 一覧（まず見る表）

| ID | 画面 | 内容 | 質問 | 優先度 |
|---|---|---|---|---|
| H-1 | Home | お知らせ欄を削除 | — | P1 |
| H-2 | Home | 見出し「体験イベント」→「この後のイベント」 | — | P1 |
| H-3 | Home | 中止のイベントカード（中止：理由、経路ボタンなし） | — | P1 |
| H-4 | Home | 次のイベントの縦線の色（アプリはオレンジ） | 要回答 | P1 |
| H-5 | Home | カテゴリの見た目（Home と一覧で不一致） | 要回答 | P1 |
| H-6 | Home | 「マップで見る」の文言・アイコン・押したときの動き | **決定（2026-11-24）**：プレビューシート展開後に案内開始で Map 遷移（2段階） | P1 |
| H-12 | 共通 | タブバー構成（4タブ → 3タブ再編） | **決定（2026-11-24）**：ホーム / マップ / 案内に再編。探すタブは廃止し Home インライン検索へ統合 | P1 |
| H-7 | Home | 開催日カードの見出し文言 | 要回答 | P2 |
| H-8 | Home | 「開催中」バッジの強さ | 要回答 | P2 |
| H-9 | Home | 当日の開催前の補足「{時刻}から公開します」、公開時間なしの「本日」 | 要回答 | P2 |
| H-10 | Home | 案内ショートカットのアイコンと入れ替え | 要回答 | P2 |
| H-11 | Home | 終了後の空表示・保存版バナー | 要回答 | P3 |
| L-1 | すべてのイベント | 0件・カテゴリ0件・保存版・読み込み中・失敗の状態 | 要回答 | P3 |
| L-2 | すべてのイベント | 件数の行の文言 | 要回答 | P2 |
| L-3 | すべてのイベント | カテゴリなしの枠の扱い（「その他」を作るか） | 要回答 | P2 |
| L-4 | すべてのイベント | 戻るボタン（iOS 18 と iOS 26 の違い） | — | P3 |
| L-5 | すべてのイベント・Home | 「経路案内は未提供です」の通知 | 要回答 | P2 |
| S-1 | 地点詳細 | イベント欄を追加 | — | P1 |
| S-2 | 地点詳細 | 中止の枠・未掲載の表示 | — | P1 |
| G-1 | 案内 | UpdateStatus を「原稿の確認日」の表示に（U-3） | — | P1 |
| G-2 | 案内 | 案内トップの目次・本日のご案内カードの扱い | 要回答 | P2 |
| T-1 | 共通 | Elevation 3段階の Effect styles | — | P1 |
| T-2 | 共通 | 押下（Pressed）状態の variant | — | P1 |
| T-3 | 共通 | ダークの Variables（Surface・カード・EventAccent・StatePressed） | — | P1 |
| T-4 | 共通 | 中止の赤（`danger` トークン） | 要回答 | P2 |
| T-5 | 共通 | 「すべて見る」の押下用の余白 | — | P3 |
| T-6 | 共通 | アクセシビリティ確認で変えた色（アクセント・中止・注意）と大きな文字での並び | — | P1 |
| P-1 | 位置情報 | 説明シート（「現在地を使いますか？」） | — | P1 |
| P-2 | 位置情報 | 「後で」・サービスオフ・機能制限の画面（拒否・取得不能・精度不足の見出しも本番の文言に） | — | P1 |
| P-3 | 位置情報 | 権限まわりのダークと最大の文字サイズ | — | P2 |
| B-1 | 位置情報 | 理由のシート（案B）を本番の部品・色で仕上げる | — | P1 |
| B-2 | 位置情報 | シートが地図左下の表記を隠す | 要回答 | P3 |
| B-3 | 位置情報 | 旧い青 `#1E6EF4` をコードの色 `#0B5ED7`（ダーク `#78AAFF`）に揃えるか | 要回答 | P1 |
| C-1 | Map | 現在地ボタン（48 pt・追従中／していない・取得中） | — | P1 |
| C-2 | Map | 現在地の点の向きの扇 | 要回答 | P3 |
| C-3 | Map | 取得中・構内にいない・取得失敗・精度不足の状態（ダーク・最大文字つき） | — | P1 |
| C-4 | Map | 位置情報オフのときの現在地ボタン | 要回答 | P2 |
| M-1 | Map | 読み込み中・掲載なし・失敗・更新が必要・未提供の状態 | — | P1 |
| M-2 | Map | 地図の状態のダークと最大の文字サイズ | — | P2 |
| W-1 | 公開サイト | トップに載せるアプリ画面1枚（地図が本番データになってから） | — | P3 |

---

## 3. Home

基準: ページ07 [Home 2798:1513](https://www.figma.com/design/WJqC7X5TuTvqTPnn40JIrV/?node-id=2798-1513)、A の状態一覧 [2790:1744](https://www.figma.com/design/WJqC7X5TuTvqTPnn40JIrV/?node-id=2790-1744)、B の状態一覧 [2791:1832](https://www.figma.com/design/WJqC7X5TuTvqTPnn40JIrV/?node-id=2791-1832)

### H-1 お知らせ欄を削除（P1）

- アプリ: Home からお知らせを外した。v1.0 ではお知らせを出さず、当日の変更はイベントの訂正・中止で伝える（EV-D2・EV-O3）。[#161](https://github.com/m0o9l0v3/NexusMobile/pull/161)、[#165](https://github.com/m0o9l0v3/NexusMobile/pull/165)
- Figma: 旧版 Home など、まだお知らせ欄が残っているフレームから削除する。ページ06・07 の下書きには入っていない。
- 質問: なし

### H-2 見出しを「この後のイベント」に（P1）

- アプリ: イベント欄の見出しを「体験イベント」から「この後のイベント」に変えた。人が選ばず、始まる順に自動で並べるため（EV-D3）。[#161](https://github.com/m0o9l0v3/NexusMobile/pull/161)
- Figma: 見出しの文言を揃える。「おすすめ」などの文言が残っていれば同じく直す。
- 質問: なし

### H-3 中止のイベントカード（P1）

- アプリ: 中止の枠も一覧に残し、「中止：{理由}」を文字で示す。アイコンは `xmark.octagon`、色は赤。経路ボタン（「マップで見る」）は出さない。次のイベントには選ばない（EV-O1）。[#161](https://github.com/m0o9l0v3/NexusMobile/pull/161)、[#168](https://github.com/m0o9l0v3/NexusMobile/pull/168)
- Figma: `HomeHIG/EventCard`（ページ07）に中止の variant を用意する（中止の行あり、経路ボタンなし）。
- 質問: なし（赤の値は T-4）

### H-4 次のイベントの縦線の色（P1・要回答）

- アプリ: オレンジ（`EventAccent`、ライト `#FF8D28`、ダーク `#FF9F40`）。[#168](https://github.com/m0o9l0v3/NexusMobile/pull/168)、[#172](https://github.com/m0o9l0v3/NexusMobile/pull/172)
- Figma: Step1 で残した旧版の見た目のまま青。
- 質問: **オレンジ（アプリ）と青（Figma）のどちらに揃えるか。**（下書き §4 質問6）

### H-5 カテゴリの見た目（P1・要回答）

- アプリ: Home のカードは色文字、「すべてのイベント」は青い文字。[#168](https://github.com/m0o9l0v3/NexusMobile/pull/168)、[#171](https://github.com/m0o9l0v3/NexusMobile/pull/171)
- Figma: Home のカードは旧版のままの色つきピル、一覧は青い文字だけ。
- 質問: **どちらの見た目に揃えるか。** 決まったら Home・一覧・地点詳細（S-1）のカテゴリを同じ部品にしてほしい。（下書き §4 質問5）

### H-6 「マップで見る」ボタンとプレビューシート（P1・決定済み）

- アプリ: 文言「マップで見る」＋マップタブと同じピンのアイコン（ページ07 どおり）。
- **決定（2026-11-24 利用者決定、[M1 v1.0 仕様決定記録](../decisions/M1-v1.0-spec-decisions.md)）**:
  - 押したときにいきなり Map タブへ遷移するのではなく、**まずその場でミニ地図・所要時間のプレビューハーフシートを表示し、「案内を開始する」ボタンをタップして初めて Map タブへ遷移する 2 段階方式**を採用（詳細は [home-3tab-search-draft.md](home-3tab-search-draft.md)）。
- Figma: ページ07 のイベントカードの「マップで見る」から展開されるプレビューハーフシートのフレームを追加する。

### H-12 タブバーの 3 タブ再編と Home インライン検索（P1・決定済み）

- **決定（2026-11-24 利用者決定）**:
  - 「探す」タブを廃止し、**「ホーム」「マップ」「案内」の 3 タブ構成**へ再編。
  - Home 画面の検索バーをタップした際は、Home 内でインラインに検索モード（カテゴリフィルター、履歴、地点一覧）が展開する（方式 B-1）。
  - 検索結果から地点を選んで Map タブへ遷移した後、Home に戻った際は前回の検索結果を保持する。キャンセルまたは Home タブの再タップで通常 Home 画面に復帰。
- Figma: ボトムタブバーの「探す」を削除して 3 等分レイアウト（ホーム / マップ / 案内）にし、Home 内の検索モード展開状態のフレームを追加する。

### H-7 開催日カードの見出し（P2・要回答）

- アプリ: 「オープンキャンパス開催日」。状態は 開催中・開催前・終了・中止 の4つ。[#168](https://github.com/m0o9l0v3/NexusMobile/pull/168)
- Figma: `HomeDraft/DayOverview`（ページ06）と Home 2798:1513 にある。
- 質問: **この文言でよいか。**（下書き §4 質問1）

### H-8 「開催中」バッジ（P2・要回答）

- アプリ: 青い塗りのバッジ。「開催中」以外のバッジはシステム色。[#168](https://github.com/m0o9l0v3/NexusMobile/pull/168)
- 質問: **青い塗りは強すぎないか。**（下書き §4 質問2）

### H-9 開催日カードの補足の行（P2・要回答）

- アプリ: Figma にない次の2つを最小の形で出している。[#168](https://github.com/m0o9l0v3/NexusMobile/pull/168)
  - 当日の公開前: 「{公開開始}から公開します」（Figma は前日以前の「開催まであと3日」だけ）
  - 当日で公開時間が決まっていない: 日付だけを出し、バッジは「本日」
- Figma: A の状態一覧 [2790:1744](https://www.figma.com/design/WJqC7X5TuTvqTPnn40JIrV/?node-id=2790-1744) にこの2つの状態を足す。
- 質問: **文言と見た目はこれでよいか。**

### H-10 案内ショートカット（P2・要回答）

- アプリ: 受付・困ったとき・アクセスの3つ。原稿に印（`homeShortcut`）の付いた記事があるものだけ出す。今は正式な原稿がないため、何も出ない（見出しごと非表示）。アイコンは仮（受付 = `person.fill`、困ったとき = `info.circle`、アクセス = `figure.walk`）。[#168](https://github.com/m0o9l0v3/NexusMobile/pull/168)、[#170](https://github.com/m0o9l0v3/NexusMobile/pull/170)
- Figma: `HomeDraft/GuidanceShortcut`、B の状態一覧 [2791:1832](https://www.figma.com/design/WJqC7X5TuTvqTPnn40JIrV/?node-id=2791-1832)
- 質問:
  1. **アイコンを決めてほしい。** 困ったときは `questionmark.circle` などに変えるか。（下書き §4 質問3）
  2. 正式な原稿と目次（E6-6 U-1〜U-3）が決まったら、3つを入れ替える必要があるか。（下書き §4 質問8）

### H-11 終了後の空表示・保存版バナー（P3・要回答）

- アプリ: Figma がないため、今の部品で最小限に出している。[#168](https://github.com/m0o9l0v3/NexusMobile/pull/168)
  - 終了後（開催日あり・この後の枠なし）: 開催日カード（終了）＋見出しの下に「この後のイベントはありません」
  - 保存版の表示中: 上に保存版バナー（`SavedHomeBannerView`、変更なし）
- 質問: **この2つを Figma で作るか。**（下書き §4 質問7）作る場合は L-1 と同じ部品にしてほしい。

## 4. すべてのイベント

基準: ページ07 [すべて 2799:1665](https://www.figma.com/design/WJqC7X5TuTvqTPnn40JIrV/?node-id=2799-1665)、[絞り込み 2799:1728](https://www.figma.com/design/WJqC7X5TuTvqTPnn40JIrV/?node-id=2799-1728)、[スクロール後 2799:1785](https://www.figma.com/design/WJqC7X5TuTvqTPnn40JIrV/?node-id=2799-1785)。部品は `EventListHIG/SlotRow`。

アプリは Figma どおりに実装した（[#171](https://github.com/m0o9l0v3/NexusMobile/pull/171)。#169 の作り直し）。枠線は `separator`。日ごとのカードは #171 では Figma どおり影なしだったが、#172 で level2 の影を付けた（T-1）。中止の行は Home と同じ（H-3）。差は次のとおり。

### L-1 Figma にない状態（P3・要回答）

- アプリ: 今の Home と同じ部品で最小限に出している。[#171](https://github.com/m0o9l0v3/NexusMobile/pull/171)

  | 状態 | 今の表示 |
  |---|---|
  | 0件 | 「公開されているイベントはありません」 |
  | 選んだカテゴリが0件 | 件数の行の下に「このカテゴリのイベントはありません」 |
  | 保存版の表示中 | 上に保存版バナー |
  | 読み込み中・失敗 | くるくる・再試行つきの表示 |

- 質問: **これらを Figma で作るか。**（下書き §4 質問7）

### L-2 件数の行（P2・要回答）

- アプリ: 「すべて：6件（開始時刻順・中止の枠も表示）」。[#171](https://github.com/m0o9l0v3/NexusMobile/pull/171)
- 質問: **この文言を正式にしてよいか。**

### L-3 カテゴリなしの枠（P2・要回答）

- アプリ: カテゴリのない枠は「すべて」でだけ出し、カテゴリ名の行を出さない。[#171](https://github.com/m0o9l0v3/NexusMobile/pull/171)
- 質問: **この扱いでよいか。「その他」の絞り込みを作るか。**

### L-4 戻るボタン（P3）

- アプリ: iOS 18 では標準の「< 戻る」、iOS 26 では Figma と同じ丸い Liquid Glass の戻るボタン（どちらも OS の標準）。[#171](https://github.com/m0o9l0v3/NexusMobile/pull/171)
- Figma: 変更不要。必要なら注記だけ足す。
- 質問: なし

### L-5 「経路案内は未提供です」の通知（P2・要回答）

- アプリ: 「マップで見る」を押すと、画面の下端に「経路案内は未提供です」の通知を出す（Home と一覧の両方）。押しても反応がないように見えたための対応。[#171](https://github.com/m0o9l0v3/NexusMobile/pull/171)
- Figma: この通知の見た目はない。
- 質問: **Figma で通知の見た目を作るか。** H-6 で「マップタブへ移す」に決まれば、この通知は要らなくなる。

## 5. 地点詳細

基準: Figma [Spot Detail 2640:1591](https://www.figma.com/design/WJqC7X5TuTvqTPnn40JIrV/?node-id=2640-1591)。このイベント欄には Figma のフレームがないため、iOS を先に最小の構成で作った（[#164](https://github.com/m0o9l0v3/NexusMobile/pull/164)）。Home・一覧の「詳細」や行をタップすると開く。

### S-1 イベント欄を追加（P1）

- アプリ: [#164](https://github.com/m0o9l0v3/NexusMobile/pull/164)
  1. 場所の行の下にイベント欄: カテゴリ（footnote・アクセント色）→ 題名（headline）→ 説明（footnote・secondary）
  2. 枠ごとの淡い色のパネル（角丸 12、余白 12）: 時計アイコン＋「8月1日 10:30〜11:15」、2行目に「終日・随時参加」、会場の行（ピン＋会場名）と右端の「経路」テキストボタン
  3. 中身がカードに収まらないときは中身だけスクロールし、「経路を確認」は下に固定
- Figma: 2640:1591 にイベント欄のフレームと部品を作る。カテゴリの見た目は H-5 の答えに揃える。経路ボタンの文言（「経路」「経路を確認」）を Home・一覧の「マップで見る」に揃えるかも H-6 とあわせて見てほしい。
- 質問: なし（H-5・H-6 に従う）

### S-2 中止の枠・未掲載（P1）

- アプリ: [#164](https://github.com/m0o9l0v3/NexusMobile/pull/164)
  - 中止の枠: 赤の「✕ 中止：{案内文}」の行を足し、「経路」ボタンを出さない
  - 未掲載のイベント: カレンダー＋！のアイコンと「このイベントは掲載されていません」の1行のパネル
- Figma: S-1 の部品にこの2つの状態を足す。
- 質問: なし

## 6. 案内

### G-1 UpdateStatus の削除（P1・決定済み）

- **決定（2026-11-24 利用者決定）**:
  - 画面上からは `UpdateStatus`（確認日バッジ等）を**完全非表示**とし、タイトルと本文のみの清潔な読み物レイアウトとする（[M1 v1.0 仕様決定記録](../decisions/M1-v1.0-spec-decisions.md)）。
  - 確認日・確認者・出典は内部データ（`GuidanceArticles.json`）でのみ保持して品質管理する。
- Figma: [Guidance/Common/UpdateStatus 2720:5366](https://www.figma.com/design/WJqC7X5TuTvqTPnn40JIrV/?node-id=2720-5366) のコンポーネントを記事詳細画面から削除する。

### G-2 案内トップの 3 分類目次（P1・決定済み）

- **決定（2026-11-24 利用者決定）**:
  - 案内トップの目次を **3 分類セクション**（①困ったとき・緊急、②当日のご案内、③学校を知る）で整理する（P09 確定）。
  - 「学校を知る」の末尾に「このアプリについて（権利表記・国土地理院出典全文）」を配置。
- Figma: 案内トップの目次を上記 3 分類セクションに整理する。

## 7. 共通・テーマ

[#172](https://github.com/m0o9l0v3/NexusMobile/pull/172) で、iOS 全体の見た目をデザインルールに揃えた。Figma の部品にも同じものを持たせてほしい。ライト・ダークのスクリーンショットは #172 の本文にある。

### T-1 Elevation 3段階（P1）

- アプリ: Web の `--elev-1/2/3` を基にした2層の影。Figma の今の影は1層（おおよそ `black 7% / blur 10 / y 2`）。

  | 段階 | Web | 使う場所 |
  |---|---|---|
  | level1 | `0 1px 2px .06` | リストのまとまり（案内・困ったとき・探す）、案内ショートカット、Home の検索欄 |
  | level2 | `0 2px 8px .08, 0 1px 3px .06` | 通常のカード（Home のイベントカード、「すべてのイベント」の日ごとのカード、状態表示） |
  | level3 | `0 4px 16px .10, 0 2px 6px .08` | 開催日カード、次のイベント |

  影の色はライト `rgb(11,27,58)`、ダークは黒で不透明度を上げる（level1 .30、level2 .36＋.24、level3 .44＋.30）。
- Figma: Effect styles に `elev-1` / `elev-2` / `elev-3`（ライト・ダーク）を作り、カード・行・開催日カード・次のイベントに当て直す。
- 質問: なし

### T-2 押下（Pressed）状態（P1）

- アプリ: アプリ独自のカード・ボタン・行に、押下時の重ね色（State layer）と、触れた位置から広がる Ripple を付けた。Reduce Motion では Ripple を出さず重ね色だけ。システムのボタン（`.bordered` など）、タブバー、ナビゲーションバー、地図のピンは OS の表示のまま。
  - State layer: ライト `rgba(11,94,215,.12)`、ダーク `rgba(120,170,255,.20)`
  - 対象: 次のイベント、イベントカードの「詳細」と「マップで見る」、「すべて見る」、案内ショートカット、Home の検索欄、カテゴリのチップ、「すべてのイベント」の行と「マップで見る」、案内・困ったときの行、探す・検索履歴の行、閉じるボタン（×）
- Figma: 上の部品に `State = Pressed` の variant を足す（State layer を重ねたもの）。Ripple はプロトタイプで表せないので、注記だけでよい。
- 質問: なし

### T-3 ダークの Variables（P1）

- アプリ: ライトとダークの両方に対応した。
  - カードの下地: ライト白、ダーク `#1C1C1E`（`secondarySystemGroupedBackground`）。カードは背景より一段明るい面になり、枠線と合わせて浮きを示す
  - `Surface` のダーク: `#1C1C1E` → `#2C2C2E`（カードの上のパネルが見えるように）
  - `EventAccent`: ライト `#FF8D28`、ダーク `#FF9F40`
  - `StatePressed`: T-2 の値
  - アクセント色の上の文字（選択中のチップ、「開催中」「中止」バッジ）：ライトは白、ダークは黒（T-6 で変更）
- Figma: Variables（`Nexus/v1.0/Review-20260908/Semantic/*`）に Dark モードの値を足し、上の値に合わせる。主要な画面（Home、すべてのイベント、地点詳細、案内、探す）にダークのフレームを用意する。
- 質問: なし

### T-4 中止の赤（P2・要回答）

- アプリ: 以前はシステムの赤（`.red`）だったが、ライトの白地で 3.6:1 と文字の基準（4.5:1）に届かないため、[#180](https://github.com/m0o9l0v3/NexusMobile/pull/180) で Asset `Cancelled`（ライト `#D70015`、ダーク `#FF6961`）を作った。
- 質問: **Figma の `danger #b42318` を `Cancelled` の値に揃えてよいか。** `#b42318` を残す場合も白地で 4.5:1 を超えるので使えるが、ダークの値を決めてほしい。

### T-5 「すべて見る」の余白（P3）

- アプリ: 押下表示のため左右に 8pt の余白を持たせた。文字の位置は変えていない。[#172](https://github.com/m0o9l0v3/NexusMobile/pull/172)
- Figma: ボタンの当たり範囲を合わせる（見た目は変わらない）。
- 質問: なし

### T-6 アクセシビリティ確認で変えたもの（P1）

- アプリ: [#180](https://github.com/m0o9l0v3/NexusMobile/pull/180)（#78 の先行確認）。WCAG AA のコントラストと、最大の文字サイズで崩れないことに合わせた。確認の手順は `docs/verification/ios-a11y-check.md`。
  - アクセント色 `AccentColor`：ライト `#1E6EF4` → `#0B5ED7`（Web の `--primary`）、ダーク `#78AAFF`（新設）
  - アクセント色・中止の塗りの上の文字 `OnAccent`：ライト白、ダーク黒。主ボタン（「経路を確認」「当日の流れ」）の文字もダークでは黒
  - 中止 `Cancelled`：ライト `#D70015`、ダーク `#FF6961`（T-4）
  - 注意（「困ったとき」）`CautionAccent`：ライト `#A84B00`、ダーク `#FF9F0A`
  - 最大の文字サイズ（AX1〜AX5）では、次のイベント・Home のイベントカードのボタン・「この後のイベント」の見出し・開催日カードの見出し・すべてのイベントの行を縦に積む。Home のイベントカードは画面幅に収める
- Figma: Variables の Accent・On accent・Danger・Caution をライト・ダークとも上の値にする。大きな文字サイズのフレームを作る場合は、上の縦積みの並びにする。
- 質問: なし

## 7A. 位置情報（権限・現在地・理由のシート）

背景: 「現在地を使う」機能が入った（[#184](https://github.com/m0o9l0v3/NexusMobile/pull/184) 権限、[#185](https://github.com/m0o9l0v3/NexusMobile/pull/185) 現在地の青い点とボタン、[#186](https://github.com/m0o9l0v3/NexusMobile/pull/186)・[#187](https://github.com/m0o9l0v3/NexusMobile/pull/187) 理由のシートを下のタブバーにつなげた）。Figma には、これらに当たる承認済みの画面がほとんどない。iOS を先に最小の形で作ったので、Figma を実装に合わせて作ってほしい。

- 画面の見本（スクリーンショット。マージしない専用ブランチに置いてある。いずれも iPhone 17 Pro・iOS 26.5。ライトとダーク）:
  - 権限: [pr-assets/ios-location-permission](https://github.com/m0o9l0v3/NexusMobile/tree/pr-assets/ios-location-permission/ios-location-permission)
  - 現在地: [pr-assets/ios-current-location](https://github.com/m0o9l0v3/NexusMobile/tree/pr-assets/ios-current-location/ios-current-location)
  - 理由のシート（案B）: [pr-assets/ios-location-sheet-attached](https://github.com/m0o9l0v3/NexusMobile/tree/pr-assets/ios-location-sheet-attached/ios-location-sheet-attached)
- 色の基準は、コードの値（Asset の名前）。名前の意味は T-6 を参照。
  - 色の基準: `AccentColor`（ライト `#0B5ED7`、ダーク `#78AAFF`）、`CautionAccent`（ライト `#A84B00`、ダーク `#FF9F0A`）、`OnAccent`（ライト白、ダーク黒）、カードの下地 `cardSurface`
- 文言はアプリのものがそのまま基準。Figma の仮の文言は直してよい。

### P-1 位置情報の説明シート（P1）

- 何を作るか: 「現在地を使う」を押したときに最初に出る、アプリ独自の説明シート。OS の許可ダイアログの前に出す。
- 画面と状態: 地図の「現在地」ボタンなどを押した直後。OS 標準のシート（下から出る）。
- アプリの内容: 見出し「現在地を使いますか？」、説明「現在地を地図に表示し、経路案内の出発地に使います。」、安心の一言（鍵のアイコン＋「現在地は Nexus のサーバーへ送りません。」）、主ボタン「位置情報を使う」、副ボタン「後で」。
- 見本: [ライト](https://github.com/m0o9l0v3/NexusMobile/blob/pr-assets/ios-location-permission/ios-location-permission/explanation-light.png?raw=true)、[ダーク](https://github.com/m0o9l0v3/NexusMobile/blob/pr-assets/ios-location-permission/ios-location-permission/explanation-dark.png?raw=true)、[最大の文字サイズ](https://github.com/m0o9l0v3/NexusMobile/blob/pr-assets/ios-location-permission/ios-location-permission/explanation-light-ax3.png?raw=true)
- Figma のノード: なし（新規）
- 主ボタンの文字色は `OnAccent`（ダークで黒）。ライトとダークの両方を用意する。

### P-2 説明のあとの状態の画面（P1）

- 何を作るか: 現在地が使えない理由ごとの表示（見出し・説明・ボタン）を、次の状態すべてについて。Figma にあるのは拒否・取得不能・精度不足の見出しだけ（保留｜04 の `Nexus/v1.0/StateMessage`、「現行の移行基準ではない」扱い）。**足りないのは下の3つ。**

  | 状態 | 見出し | Figma |
  |---|---|---|
  | 「後で」を選んだ | 「現在地は使っていません」（出発地を自分で選ぶ。次の操作でもう一度確認する） | なし |
  | 位置情報サービスがオフ | 「位置情報サービスがオフです」（設定を開くボタンあり） | なし |
  | 機能制限（この端末では使えない） | 「この端末では位置情報を使えません」（設定を開くボタンは出さない） | なし |
  | 拒否 | 「位置情報が許可されていません」 | 見出しのみ |
  | 取得不能 | 「現在地を取得できません」（もう一度試す） | 見出しのみ |
  | 精度不足 | 「位置の精度が足りません」（設定を開く） | 見出しのみ |

- 見本（ライト／ダーク）: [後で](https://github.com/m0o9l0v3/NexusMobile/blob/pr-assets/ios-location-permission/ios-location-permission/deferred-light.png?raw=true) / [ダーク](https://github.com/m0o9l0v3/NexusMobile/blob/pr-assets/ios-location-permission/ios-location-permission/deferred-dark.png?raw=true)、[サービスオフ](https://github.com/m0o9l0v3/NexusMobile/blob/pr-assets/ios-location-permission/ios-location-permission/servicesOff-light.png?raw=true) / [ダーク](https://github.com/m0o9l0v3/NexusMobile/blob/pr-assets/ios-location-permission/ios-location-permission/servicesOff-dark.png?raw=true)、[機能制限](https://github.com/m0o9l0v3/NexusMobile/blob/pr-assets/ios-location-permission/ios-location-permission/restricted-light.png?raw=true) / [ダーク](https://github.com/m0o9l0v3/NexusMobile/blob/pr-assets/ios-location-permission/ios-location-permission/restricted-dark.png?raw=true)
- 6つの状態は同じ部品の見出し・説明・ボタンの組み合わせでよい。シートの形は B-1。

### P-3 権限まわりのダークと大きな文字（P2）

- 何を作るか: P-1・P-2 のすべてのダーク版と、最大の文字サイズ（AX）の版。
- アプリの動き: 最大の文字サイズでは、内容が画面の高さの6割を超えないようにし、超える分は中でスクロールする。「出発地を自分で選ぶ」などのボタンが下にあるので、スクロールした状態も見せてほしい。
- 見本: [拒否・AX](https://github.com/m0o9l0v3/NexusMobile/blob/pr-assets/ios-location-permission/ios-location-permission/denied-light-ax3.png?raw=true)、[スクロール後](https://github.com/m0o9l0v3/NexusMobile/blob/pr-assets/ios-location-permission/ios-location-permission/denied-light-ax3-scrolled.png?raw=true)

### B-1 理由のシート（案B）を本番の部品・色で仕上げる（P1）

- 背景: 理由の表示がタブバーの上に平らに切れて見えた問題を、オーナーが Figma の案B「浮いたシートがタブバーを包む」に決めて直した（2026-11-14）。案Bは下書き用の部品と変数で作ってあり、そのままでは使えない。
- 何をするか: 案Bのフレームを、本番の部品と変数に置き換えて仕上げる。
  - いま使っている下書き: 部品 `LocationDraft/ActionButton`・`LocationDraft/StatusHeader`、変数 `Nexus/v1.0/LocationDraft-2026-11`
  - 置き換え先: 本番の部品（ボタン、状態の見出し）と、`Nexus/v1.0/Review-20260908/Semantic/*` の変数
- 画面と状態: Map タブ。拒否・取得不能・精度不足の各ライト／ダーク、精度不足の最大文字サイズ（スクロール）。
- 形（アプリの実寸）: 左右と下を 8 空けた浮いた面。上の角は 28。下の角は画面の角と同心（iOS 26）。iOS 18 は下の角も 28 で固定。中身はタブバーの上端から 16 空けて終える。タブバーの色や形は変えない（OS の標準）。
- Figma のノード（ページ「v1.0 | 現在地UI 下部バー連結 案｜2026-11」[2808:1520](https://www.figma.com/design/WJqC7X5TuTvqTPnn40JIrV/?node-id=2808-1520)）:

  | 状態 | ライト | ダーク |
  |---|---|---|
  | 拒否 | [2812:1710](https://www.figma.com/design/WJqC7X5TuTvqTPnn40JIrV/?node-id=2812-1710) | [2812:1986](https://www.figma.com/design/WJqC7X5TuTvqTPnn40JIrV/?node-id=2812-1986) |
  | 取得不能 | [2812:1804](https://www.figma.com/design/WJqC7X5TuTvqTPnn40JIrV/?node-id=2812-1804) | [2812:2077](https://www.figma.com/design/WJqC7X5TuTvqTPnn40JIrV/?node-id=2812-2077) |
  | 精度不足 | [2812:1895](https://www.figma.com/design/WJqC7X5TuTvqTPnn40JIrV/?node-id=2812-1895) | [2812:2168](https://www.figma.com/design/WJqC7X5TuTvqTPnn40JIrV/?node-id=2812-2168) |
  | 精度不足・最大文字 | [2812:2259](https://www.figma.com/design/WJqC7X5TuTvqTPnn40JIrV/?node-id=2812-2259) | |

  比べた案A（[2810:1514](https://www.figma.com/design/WJqC7X5TuTvqTPnn40JIrV/?node-id=2810-1514)）・案C（[2813:1926](https://www.figma.com/design/WJqC7X5TuTvqTPnn40JIrV/?node-id=2813-1926)）は、残すか片づけるかをデザイナーが決めてよい。経緯は [location-sheet-attached-draft.md](location-sheet-attached-draft.md)。
- アプリの見た目: [精度不足・ライト](https://github.com/m0o9l0v3/NexusMobile/blob/pr-assets/ios-location-sheet-attached/ios-location-sheet-attached/reducedAccuracy-light.png?raw=true)、[ダーク](https://github.com/m0o9l0v3/NexusMobile/blob/pr-assets/ios-location-sheet-attached/ios-location-sheet-attached/reducedAccuracy-dark.png?raw=true)、[取得不能](https://github.com/m0o9l0v3/NexusMobile/blob/pr-assets/ios-location-sheet-attached/ios-location-sheet-attached/unavailable-light.png?raw=true)、[最大文字](https://github.com/m0o9l0v3/NexusMobile/blob/pr-assets/ios-location-sheet-attached/ios-location-sheet-attached/reducedAccuracy-light-ax3.png?raw=true)、[iOS 18](https://github.com/m0o9l0v3/NexusMobile/blob/pr-assets/ios-location-sheet-attached/ios-location-sheet-attached/reducedAccuracy-light-ios18.png?raw=true)
- 質問: なし（色は B-3）

### B-2 シートが地図の左下の表示を隠す（P3・要回答）

- アプリ: シートが出ている間、地図の左下の「マップ」と「法律に基づく情報」の表記がシートに隠れる（Apple のマップのシートと同じ動き）。
- 質問: **これでよいか。気になる場合は、シートが出ている間だけ地図の表示位置を上げる案もある。** 判断はデザイナーとオーナーで。

### B-3 旧い青 `#1E6EF4` をコードの色に揃えるか（P1・要回答）

- 背景: アプリのアクセント色は [#180](https://github.com/m0o9l0v3/NexusMobile/pull/180) で `#1E6EF4` から `#0B5ED7`（ダーク `#78AAFF`）に変わった（T-6）。一方 Figma の `Review-20260908/Semantic/tint` は旧値 `#1E6EF4` のまま。案Bはこの旧値の上に作ってある。
- 質問: **`tint` をコードの色（ライト `#0B5ED7`、ダーク `#78AAFF`）に揃えてよいか。** 揃える場合、案Bをはじめ `tint` を使うフレームの色も一緒に変わる。T-6 の「Variables の Accent」と同じ作業なので、まとめて直してほしい。

### C-1 現在地ボタン（P1）

- 何を作るか: 地図の右下に出る「現在地」ボタン。大きさと、追従中・追従していないの2状態の見た目。
- 画面と状態: Map タブ。右下、詳細カードの上（タブバーの上）。
- アプリ: 直径 48 pt の円（最大の文字サイズでは 64 pt まで広がり、記号も一緒に大きくなる）。`cardSurface` の円にアクセント色の記号。
  - 追従中: 塗りの `location.fill`
  - 追従していない（地図を動かした）: 線の位置記号
  - 取得中: 進行表示（くるくる）
- Figma のノード: ページ「Map Event Pins Exploration」の `CurrentLocationButton__ComponentCandidate__active-fixed45` / `inactive`（45 pt。探索段階の候補で、承認版ではない）。位置は合わせてある。
- 直すところ: 45 → 48 pt（と最大文字の 64 pt）、追従中と追従していないの違いが分かる見た目、取得中の見た目。
- 見本: [追従中](https://github.com/m0o9l0v3/NexusMobile/blob/pr-assets/ios-current-location/ios-current-location/following-light.png?raw=true) / [ダーク](https://github.com/m0o9l0v3/NexusMobile/blob/pr-assets/ios-current-location/ios-current-location/following-dark.png?raw=true)、[取得中](https://github.com/m0o9l0v3/NexusMobile/blob/pr-assets/ios-current-location/ios-current-location/locating-light.png?raw=true)、[追従を止めた・ダーク](https://github.com/m0o9l0v3/NexusMobile/blob/pr-assets/ios-current-location/ios-current-location/panned-dark.png?raw=true)

### C-2 青い点の向きの扇（P3・要回答）

- アプリ: 現在地の点はアクセント色の塗りに `OnAccent` の縁。**向きの扇（heading cone）は実装していない。**
- Figma: 候補には向きの扇が付いている。
- 質問: **扇は付けるか、外すか。** 方位の取得は実機での確認（#80）のあとに決めるので、いまは Figma の候補を残すかどうかだけ決めてほしい。

### C-3 現在地まわりの状態（P1）

- 何を作るか: Figma にない次の状態。いずれもライト・ダーク・最大の文字サイズで。

  | 状態 | アプリの表示 | 見本 |
  |---|---|---|
  | 取得中 | ボタンが進行表示 | [ライト](https://github.com/m0o9l0v3/NexusMobile/blob/pr-assets/ios-current-location/ios-current-location/locating-light.png?raw=true) |
  | 構内にいない | 検索欄の下に `cardSurface` のカード。`CautionAccent` の記号＋「構内から離れています」「現在地の点は表示しますが、地図は構内のままにします。」。出たときに読み上げ。最大文字では記号が見出しの上に来る | [ライト](https://github.com/m0o9l0v3/NexusMobile/blob/pr-assets/ios-current-location/ios-current-location/offCampus-light.png?raw=true) / [ダーク](https://github.com/m0o9l0v3/NexusMobile/blob/pr-assets/ios-current-location/ios-current-location/offCampus-dark.png?raw=true) / [最大文字](https://github.com/m0o9l0v3/NexusMobile/blob/pr-assets/ios-current-location/ios-current-location/offCampus-light-ax3.png?raw=true) |
  | 取得失敗（15秒で取れない） | P-2 の「取得不能」を地図の上で使う（B-1 のシート） | [ライト](https://github.com/m0o9l0v3/NexusMobile/blob/pr-assets/ios-current-location/ios-current-location/failure-light.png?raw=true) / [ダーク](https://github.com/m0o9l0v3/NexusMobile/blob/pr-assets/ios-current-location/ios-current-location/failure-dark.png?raw=true) |
  | 精度不足（一時的な正確な位置を断った） | P-2 の「精度不足」を地図の上で使う | [ライト](https://github.com/m0o9l0v3/NexusMobile/blob/pr-assets/ios-current-location/ios-current-location/reducedAccuracy-light.png?raw=true) / [ダーク](https://github.com/m0o9l0v3/NexusMobile/blob/pr-assets/ios-current-location/ios-current-location/reducedAccuracy-dark.png?raw=true) |

### C-4 位置情報オフのときのボタン（P2・要回答）

- アプリ: 位置情報が使えない（拒否・サービスオフ・機能制限）とき、現在地ボタンの記号が斜線入りの `location.slash`（色は `CautionAccent`）になる。押すと B-1 のシートが出る。Map を開いただけでは何も出さない。[#193](https://github.com/m0o9l0v3/NexusMobile/pull/193)
- Figma: ページ「Map Event Pins Exploration」に `CurrentLocationButton__ComponentCandidate__inactive-reference-off-canvas`（[2436:1485](https://www.figma.com/design/WJqC7X5TuTvqTPnn40JIrV/?node-id=2436-1485)）がある。ただしこれが「位置情報オフ」を表すのかは決まっていない。
- 質問: **2436:1485 は「位置情報オフ」の見た目として使えるか。使えないなら、斜線＋注意色の見た目をデザイナーが決めてほしい。**
- 見本: [ボタン](https://github.com/m0o9l0v3/NexusMobile/blob/pr-assets/ios-map-states/ios-map-states/locationOff-light.png?raw=true) / [ダーク](https://github.com/m0o9l0v3/NexusMobile/blob/pr-assets/ios-map-states/ios-map-states/locationOff-dark.png?raw=true)、[押したあと](https://github.com/m0o9l0v3/NexusMobile/blob/pr-assets/ios-map-states/ios-map-states/locationOffSheet-light.png?raw=true)

## 7B. 地図の状態

背景: [#193](https://github.com/m0o9l0v3/NexusMobile/pull/193)。Map タブで、地図が出せないときの表示を作った。Figma の「Map Event Pins Exploration」は正常な状態だけで、これらのフレームはない。Home・探すの状態表示（`NexusStatusView`）に揃えた**仮の見た目と文言**で作ったので、Figma で正式にしてほしい。

### M-1 地図が出ないときの状態（P1）

- 何を作るか: 次の5つの状態。画面全体（地図の面）に出す状態表示。背景は `Surface`。

  | 状態 | 見出し | 説明・動き | 見本 |
  |---|---|---|---|
  | 読み込み中 | 「地図を読み込み中」 | 進行表示。1つのまとまりとして読み上げ | [ライト](https://github.com/m0o9l0v3/NexusMobile/blob/pr-assets/ios-map-states/ios-map-states/loading-light.png?raw=true) / [ダーク](https://github.com/m0o9l0v3/NexusMobile/blob/pr-assets/ios-map-states/ios-map-states/loading-dark.png?raw=true) |
  | 掲載なし（まだ公開していない） | 「構内地図はまだ公開されていません」 | 公開されれば次の確認で地図が出る。「再試行」は出さない | [ライト](https://github.com/m0o9l0v3/NexusMobile/blob/pr-assets/ios-map-states/ios-map-states/notPublished-light.png?raw=true) / [ダーク](https://github.com/m0o9l0v3/NexusMobile/blob/pr-assets/ios-map-states/ios-map-states/notPublished-dark.png?raw=true) |
  | 失敗（通信） | 「地図を読み込めませんでした」 | 「通信できる場所で再試行してください。掲載が無いわけではありません。」＋「再試行」ボタン | [ライト](https://github.com/m0o9l0v3/NexusMobile/blob/pr-assets/ios-map-states/ios-map-states/failed-light.png?raw=true) / [ダーク](https://github.com/m0o9l0v3/NexusMobile/blob/pr-assets/ios-map-states/ios-map-states/failed-dark.png?raw=true) |
  | 失敗（アプリの更新が必要） | 失敗と同じ形 | 「この地図データは今のアプリでは読めません。App Store で Nexus を更新してください。」＋「再試行」 | [ライト](https://github.com/m0o9l0v3/NexusMobile/blob/pr-assets/ios-map-states/ios-map-states/updateRequired-light.png?raw=true) / [ダーク](https://github.com/m0o9l0v3/NexusMobile/blob/pr-assets/ios-map-states/ios-map-states/updateRequired-dark.png?raw=true) |
  | 未提供（接続先がない。今の本番） | 「構内地図は未提供です」 | 「地図データの接続後に、建物・階と地点を表示します。」。再試行なし | [ライト](https://github.com/m0o9l0v3/NexusMobile/blob/pr-assets/ios-map-states/ios-map-states/unavailable-light.png?raw=true) / [ダーク](https://github.com/m0o9l0v3/NexusMobile/blob/pr-assets/ios-map-states/ios-map-states/unavailable-dark.png?raw=true) |

- 「未提供」と「掲載なし」は意味が違う（未提供は接続先がないビルドで決まる状態、掲載なしは接続先から「まだ公開していない」と返った状態）ので、**同じ置き場所・同じ部品で、文言だけ違うものとして描き分けてほしい。** どちらも「再試行」は出さない。
- これらの状態では現在地ボタンを出さない。
- 質問: なし（見た目・文言はお任せ。変えたい文言があれば返信で）

### M-2 地図の状態のダークと大きな文字（P2）

- 何を作るか: M-1 のすべてのダーク版と最大文字サイズ版。
- アプリの動き: 最大の文字サイズでは検索欄が大きくなるので、状態表示の上の余白もそれに合わせて広がる。内容が収まらないときだけスクロールし、スクロールすると「再試行」に届く。
- 見本: [失敗・最大文字](https://github.com/m0o9l0v3/NexusMobile/blob/pr-assets/ios-map-states/ios-map-states/failed-light-ax3.png?raw=true)、[スクロール後](https://github.com/m0o9l0v3/NexusMobile/blob/pr-assets/ios-map-states/ios-map-states/failed-light-ax3-scrolled.png?raw=true)

## 7C. 公開サイト（Web）

背景: 公開サイト（[#131](https://github.com/m0o9l0v3/NexusMobile/issues/131)）を作り直した（[#188](https://github.com/m0o9l0v3/NexusMobile/pull/188)・[#196](https://github.com/m0o9l0v3/NexusMobile/pull/196)・[#201](https://github.com/m0o9l0v3/NexusMobile/pull/201)・[#203](https://github.com/m0o9l0v3/NexusMobile/pull/203)）。見た目の方向（スイス風の白黒・罫線・ライト／ダーク）はオーナーが決め、コードで作ってあるので、**サイト全体のデザインを Figma で起こす依頼はない。** デザイナーに頼みたいのは次の1点だけ。

### W-1 トップページに載せるアプリ画面（P3）

- 何を作るか: トップページの右側（スマホでは先頭）に置く、アプリの画面1枚。
- 決まっていること（オーナー決定）:
  - ライトの1枚だけ。ダーク切り替えはしない
  - iPhone 17 Pro（Deep Blue）の枠に入れる。枠は Apple 公式の素材を使い、書き出し済みの合成画像だけをリポジトリに入れる
  - 撮る時期は、**Map が本番の地図データになってから**。それまでトップは画像なしで公開している（画像の枠ごと隠れる）
- デザイナーに頼むこと: どの画面・どの状態を見せるか（候補は Home か Map）と、アプリの文言・日付が本物に見えるサンプルになっているかの確認。撮影はオーナー側で行い、承認した1枚だけを使う。
- 参考: 公開前の App Store のボタンは、Apple 公式のバッジ（日本語）を使い、公開までは「App Store で近日公開」の文字を出している。
- 優先度: 地図が本番データになるまで着手できないため P3。

## 8. この依頼の範囲外

- Figma の編集はデザイナーが行う。この文書を作った側では Figma を変えていない。
- 経路案内そのもの（マップタブへ移す動き）の実装、案内の正式な原稿（U-1・U-2）は、オーナー側の作業。

## 9. デザイナーへの連絡文（オーナーが送る）

```
お疲れさまです。iOS を先に直した分の Figma 反映をお願いしたく、依頼を1つの文書にまとめました。
docs/design/figma-handoff-2026-11.md（develop に入ります）
画面ごと（Home・すべてのイベント・地点詳細・案内・共通テーマ）に、アプリの変更・Figma で直すところ・優先度を並べています。
まず P1 をお願いします。お知らせ欄の削除と見出しの変更、中止のカード、地点詳細のイベント欄、案内の「確認日」表示、Elevation・押下状態・ダークの Variables です。
新しく、位置情報（P-・B-・C-）、地図の状態（M-）、公開サイト（W-）の項目を足しました。P1 は、位置情報の説明シートと各状態の画面（P-1・P-2）、理由のシートの仕上げ（B-1）、現在地ボタンと状態（C-1・C-3）、地図の状態（M-1）です。B-3 は、アクセントの青をコードに揃えるかの判断で、T-6 とあわせて早めに決めてもらえると助かります。
「要回答」の質問が18件あります（今回の追加は B-2・B-3・C-2・C-4 の4件）。特に、次のイベントの縦線の色、カテゴリの見た目、「マップで見る」の扱い、の3つを先に決めてもらえると助かります。
基準はページ07（HIG修正版）です。回答は文書へのコメントか、このメッセージへの返信でお願いします。
```
