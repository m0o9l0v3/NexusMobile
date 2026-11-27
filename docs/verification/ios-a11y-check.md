# iOS アクセシビリティ確認手順（#78）

[#78](https://github.com/m0o9l0v3/NexusMobile/issues/78)（E9-5）の観点を、何度でも同じ手順で確かめられるようにまとめた文書です。
対象は `apps/nexus-ios/` の SwiftUI 画面です。デザインの基準は [`docs/design-rules.md`](../design-rules.md)（書いていないことは Apple HIG）です。

#78 の進め方は「SwiftUI で先行確認 → #87 の統合試験・TestFlight 実機確認 → #30 の整理後に影響を再確認」です。
この文書の手順は、どの段階でもそのまま使います。段階ごとの結果は末尾の「実施記録」に追記します。

## 1. 対象と環境

### 画面

| 画面 | 開き方（DEBUG ビルド） | 見る状態 |
|---|---|---|
| Home | `-NexusPreviewData` | 検索入口、開催日カード、案内ショートカット、次のイベント、この後のイベント（中止のカードを含む。横にスクロールして最後のカード） |
| Home 内インライン検索 | `-NexusPreviewData -NexusPreviewScreen search`（または Home の検索欄をタップ） | 検索欄、カテゴリチップ、履歴・一覧、キャンセル／ホームタブ再タップ復帰 |
| すべてのイベント | Home の「すべて見る」 | 大見出し（Large）／インライン見出し（AX1〜AX5）、カテゴリの絞り込み、中止の行 |
| Map 地点詳細（イベント欄・出発地選択） | `-NexusPreviewData -NexusPreviewScreen eventDetail` / `-NexusManualRouteCheck hgr_a` | 枠3件（うち1件が中止）、AX5 でのスクロール領域、下部の「マップで見る」・出発地選択 |
| 案内トップ | `-NexusPreviewData -NexusPreviewScreen guidance` | 3分類セクション（困ったとき・緊急／当日のご案内／学校を知る） |
| 案内の記事 | `-NexusPreviewData -NexusPreviewScreen guidanceStandard`（ほか `guidanceHelp` / `guidanceAccess` / `guidanceFAQ` / `guidanceRelatedPlace`） | 見出し、本文、関連する場所（確認日・出典は画面非表示） |
| 同梱案内・空の状態 | 通常起動して案内タブを開く。空状態の試験では、検証用の `GuidanceArticles.json` で `articles` だけを空配列にして同じ操作を行う | 通常は同梱10記事と「このアプリについて」の11項目で「準備中」は0件。空配列の場合に記事項目が「準備中」になり、「このアプリについて」は引き続き開ける |
| Map の検索 | `-NexusPreviewData -NexusPreviewScreen map` | 検索欄の閉じた状態・開いた状態、検索確定、入力の消去 |
| 保存版・7日失効 | `-NexusSearchCheck saved` 等 | 保存版バナー（版・日時）、7日失効時の再試行案内 |

Map の地図・経路は調査データ待ちのため、Map の本確認は Map の作業の後に行います（#78 は閉じない）。

### 端末と設定

- 小さい端末：iPhone 16e / iPhone 17e（または iPhone SE 第3世代）
- 標準の端末：iPhone 16 / iPhone 17
- **iOS のバージョン**：Deployment Target の iOS 18 と、参加者の多くが使う最新の iOS（26 以降）の両方。iOS 26 からはタブバー・ナビゲーションバーが Liquid Glass になり、`NexusAvailabilityShims.swift` の分岐（地図の上に浮くパネルの縁取り）も変わるため、見た目とレイアウトは両方で見る
- それぞれ **ライト・ダーク** × **文字サイズ 標準（Large）・最大（AX5）** の4通り

シミュレーターの設定は次のコマンドで切り替えます。

```bash
xcrun simctl ui <UDID> appearance light            # dark
xcrun simctl ui <UDID> content_size large          # accessibility-extra-extra-extra-large
xcrun simctl launch <UDID> jp.nexus-app.mobile -NexusPreviewData -NexusPreviewScreen eventDetail
xcrun simctl io <UDID> screenshot <file>.png
```

スクロールやタップは Xcode の Simulator を手で操作します。

## 2. 自動で確かめるもの

単体試験（Scheme `Nexus`）に含まれていて、全体の試験と一緒に毎回走ります。

```bash
xcodebuild -project apps/nexus-ios/Nexus.xcodeproj -scheme Nexus -destination 'platform=iOS Simulator,id=<UDID>' test
# 観点2・4だけを流すとき
xcodebuild ... test -only-testing:NexusTests/AccessibilityContrastTests -only-testing:NexusTests/AccessibilityTextTests
```

| 試験 | 観点 | 内容 |
|---|---|---|
| `AccessibilityContrastTests` | 4 コントラスト | Asset Catalog の色（AccentColor・OnAccent・Cancelled・CautionAccent・Surface）とシステムの下地を、ライトとダークそれぞれで解決して比を計算する。半透明の下地（`tintSurface` など）は下の面と重ねてから比べる。本文の文字で 4.5:1 以上 |
| `AccessibilityTextTests` | 2 VoiceOver | Home のカード・次のイベント・一覧の行・地点詳細の枠の読み上げ文。中止は先頭で「中止」と読む。「詳細」「マップで見る」はイベント名を添える |

読み上げ文は View ではなくモデルの拡張（`Shared/Models/EventAccessibilityText.swift`）に置き、試験できるようにしています。
新しい色の組み合わせや読み上げ文を足したら、ここにも試験を足します。

### F-7 主要画面の XCUITest（任意実行）

共有 Scheme `Nexus Accessibility` は DEBUG の固定データで各画面を起動し、3タブ構成（ホーム／マップ／案内）の Home 開催日カード、Home 内インライン検索の「2A教室」の行、案内トップの「受付のご案内」ボタン、Map の地図未公開メッセージが現れるのをそれぞれ待ちます（あわせて 3タブ・Home インライン検索の往復フローを `HomeSearchFlowTests` で検証します）。Map は位置情報を拒否した固定状態です。

各画面の初期表示に対し、`performAccessibilityAudit` でコントラスト、要素の検出、タップ領域、要素の説明、Dynamic Type、文字切れ、アクセシビリティ特性（traits）を検査します。指摘があればテストが失敗し、対象要素の情報は Xcode で `.xcresult` を開いて確認できます。許容する指摘は、F-1 の補足、タブバーの下に入った要素、Home の飾りの記号の縁などに限ります。理由は試験のコメントと [2026-11-27 の記録](#2026-11-27-画面監査の既知の失敗の解消) にあります。

リポジトリのルートから次を実行します。端末名と OS は手元のシミュレーターに合わせて変更できます。

```bash
audit_run=$(mktemp -d)
audit_args=(-project apps/nexus-ios/Nexus.xcodeproj -scheme 'Nexus Accessibility'
  -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16e,OS=18.6'
  -derivedDataPath "$audit_run/DerivedData" -parallel-testing-enabled NO)
xcodebuild "${audit_args[@]}" build-for-testing &&
  xcodebuild "${audit_args[@]}" -resultBundlePath "$audit_run/Audit.xcresult" test-without-building
```

既存の必須 CI は Scheme `Nexus` の単体試験を実行します。UI 監査は画面外の要素、実際の地図・経路、実機での VoiceOver の読み上げ順・フォーカス順を対象にしていません。ライト・ダークや最大文字サイズでの操作は、引き続き下の手順で確かめます。

## 3. 観点ごとの手順と判定

判定は「合格」「不合格」「要実機」の3つです。不合格は重さを付けて「指摘」に載せます。

| 重さ | 目安 |
|---|---|
| 高 | 情報や操作に届かない（文字が切れて読めない、ボタンが押せない、中止が伝わらない） |
| 中 | 届くが、読みにくい・探しにくい（基準をわずかに下回る、狭い表示域でのスクロールが必要） |
| 低 | 基準は満たすか、システムの部品の振る舞いで、直すと見た目が変わるもの |

### 観点1 タップ領域（44×44pt 以上）

手順：
1. 各画面で、押せるもの（ボタン・行・チップ・閉じる×・「すべて見る」・「経路」）を一覧にする。
2. コードで、押せる範囲の `frame` が `NexusTheme.minimumTapTarget`（44）以上か、`.controlSize(.large)` か、行なら `nexusTappableRow` かを確かめる。`NexusPressableButtonStyle` は大きさを変えないので、ラベル側の `frame` と `contentShape` を見る。
3. 迷うものは Xcode の View Debugger か Accessibility Inspector で枠の大きさを測る。

判定：
- 合格：押せる範囲が縦横とも 44pt 以上。
- 不合格：どちらかが 44pt 未満（アプリ独自の部品）。
- システムの部品（タブバー、ナビゲーションバー、`Picker(.segmented)`）は HIG どおりなら合格とし、44pt 未満でも「低」の指摘に留める。

### 観点2 VoiceOver

手順：
1. 単体試験 `AccessibilityTextTests` が通ることを確かめる。
2. コードで、次を確かめる。
   - 記号だけのボタン（×、矢印）に日本語の `accessibilityLabel` がある。
   - 飾りの画像・区切り線に `accessibilityHidden(true)` がある。
   - 同じ名前のボタンが並ぶ場所（カードの「詳細」など）は、名前で区別できる。
   - 見出しに `.isHeader`、選択中のチップに `.isSelected` がある。
   - まとまり（チップの列など）に名前を付けるときは `accessibilityElement(children: .contain)` を使い、子の読み上げを消さない。
3. **実機**で VoiceOver をオンにし、各画面を右スワイプで頭から順にたどる。ローターの「見出し」でも移動する。

判定：
- 合格：すべての操作に意味の分かる日本語の名前がある。順番が見た目の上から下（Home は検索 → 開催日 → 次のイベント → 案内 → この後のイベント）。飾りに止まらない。中止の枠は「中止」と読む。
- 不合格：名前のない操作、英語や ID の読み上げ、飾りへのフォーカス、中止が読まれない。
- シミュレーターだけで終えたときは「要実機」とする。

### 観点3 Dynamic Type（最大のアクセシビリティサイズまで）

手順：
1. 文字サイズを `accessibility-extra-extra-extra-large`（AX5）にして、各画面を上から下まで、横スクロールの列は端までスクロールして撮る。
2. 標準（Large）でも同じ画面を撮り、崩れていないことを確かめる。

判定：
- 合格：文字が切れない・重ならない。横に並べると1文字ずつ折り返すものは縦に積む（`dynamicTypeSize.isAccessibilitySize` で `AnyLayout` を切り替える）。カードは画面からはみ出さない。
- 不合格：文字の欠け・重なり、画面外にはみ出して届かない操作、1文字ずつの折り返しで読めない。
- スクロールで読めるが表示域がとても狭いものは「中」。

### 観点4 コントラスト（WCAG AA）

手順：
1. 単体試験 `AccessibilityContrastTests` が通ることを確かめる。
2. 新しい色や下地を使った画面は、その組み合わせを試験に足す。
3. 試験にない組み合わせ（画像の上の文字など）は、スクリーンショットから色を取って計算する。

判定：
- 本文の文字：4.5:1 以上。大きな文字（18pt 以上、または 14pt 以上の太字）：3:1 以上。
- UI 部品・意味のある記号：隣の色と 3:1 以上。飾りは対象外。
- ライト・ダークの両方で満たす。
- システムの色（`secondaryLabel` など）は HIG に従う前提で、基準を下回るものは指摘に載せて扱いを決める。

iOS 26 以降では、次も確かめます。
- 下に浮くタブバー（Liquid Glass）の後ろに内容が回り込むため、各画面を一番下までスクロールし、最後の内容がタブバーの上で止まって読める・押せること。
- 地図の上に浮くパネル（`nexusFloatingSurface`）は半透明の下地なので、後ろの地図によって文字のコントラストが変わる。地図を表示した状態で確かめる。

### 観点5 視差効果を減らす（Reduce Motion）

手順：
1. コードで、動きを出す処理（`withAnimation`、`.animation`、`scaleEffect`、`.transition`）を検索し、`accessibilityReduceMotion` で止めているかを確かめる。
2. 実機またはシミュレーターで「設定 > アクセシビリティ > 動作 > 視差効果を減らす」をオンにし、カード・行・チップを長めに押す。

判定：
- 合格：Ripple（広がる円）が出ず、押下は State layer（重ね色）の色の変化だけ。地図の移動は動きなしで切り替わる。
- 不合格：Reduce Motion でも拡大・移動の動きが出る。

## 4. 実施記録

### 2026-11-27 画面監査の既知の失敗の解消

`Nexus Accessibility` の監査を、iPhone 16e（iOS 18.6）のライト・Large で、`origin/develop`（`e66bb93`）から流し直した。11-25 の19指摘のうち `textClipped` の1件は、それまでの修正で消えていた。残る18件に加え、案内の Liquid Glass 化（PR #245〜#247）の後は `testGuidance` でも2件の指摘が出た。指摘の要素は、監査の結果に要素の名前と位置を一時的に書き出して特定した。

| 指摘 | 原因 | 対応 |
|---|---|---|
| Home 次のイベントの「テクノロジー」「検討用」の Dynamic Type（2件） | `.caption2` の文字を、監査が「文字サイズの変更に一部しか追従しない」と判定した | `NextEventSummaryView` と `HomeEventCardView` のカテゴリ・補足を `.caption` に変更。指摘が消えた |
| Map 未公開の見出し・説明の Dynamic Type（2件） | `MapSurfaceStateView` の `ViewThatFits`（中央表示とスクロールの切替） | 常に `ScrollView` に置き、内容が収まるときは中央に表示する形に変更。指摘が消えた。Large で中央表示、AX5 でスクロールして末尾まで読めることを確認した。AX5 の eventDetail も応答が止まらない |
| F-1 `secondaryLabel` の補足（Home 6件、Map 1件） | M1 の F-1 決定で継続使用 | `testSearch` と同じく、画面ごとに文言を列挙して許容する（`acceptsSecondaryLabel`）。Home 検索入口の案内文は Surface（`#F7F7F7`）の上にあり、白地より低い約3.2:1。ほかの補足と同じく F-1 の決定の範囲として扱った |
| Home 案内ショートカット「困ったとき」「アクセス」のコントラスト（2件） | 読み上げない飾りの記号の、細い線の縁の中間色。記号を透明にすると指摘が消えた。太さを semibold にしても消えなかった | 許容する。記号の AccentColor は Surface の上で本文基準 4.5:1 を満たす（`testAccentTextMeetsAA`） |
| Home「この後のイベント」のカードの文字（5件）、案内トップ下端の「よくある質問（FAQ）」「このアプリについて」（2件） | 半透明のタブバーの下に入った要素が、タブバー越しの色で判定される。カードは1枚が1つの読み上げ要素のため、中の文字は要素を特定できない（element が nil） | タブバーと重なる要素のコントラスト指摘は、全画面で許容する。Home の要素を特定できないコントラスト指摘も許容する。カードの文字色は単体試験で確かめる |

結果：`Nexus Accessibility` の9件（監査8件と `HomeSearchFlowTests`）がすべて通過した。単体680件も全件通過した（Scheme `Nexus`、iPhone 17e）。F-8（実機 VoiceOver）と F-10（正式地図上のパネル）は段階 B のまま残る。

監査の画面外の要素は、引き続き確認の対象外。タブバーの下や横スクロールの先にある要素は、スクロールして目で確かめる。

### 2026-11-25 PR #239・#240・#242 統合後の確認と AX5 地点詳細のハング修正

iPhone 17e（iOS 27.0）のダーク・AX5 でイベントの地点詳細を開くと応答が止まった。`MapRootView` と `MapKitMapSurfaceView` の余白計測を分離し、`SpotDetailCardView` の AX 縦余白を調整した。修正後は再現端末、iPhone 16e（iOS 18.6）、iPhone 17（iOS 27.0）で応答を確認した。末尾の中止理由までスクロールでき、地図出典・Apple Maps Legal・現在地ボタンの非重なりも確認した。

`AccessibilityAuditTests` は同梱案内10記事に合わせて更新した。単体677件が全通過し、Release 無署名ビルドも成功した。XCUITest は7件中5件合格。失敗は従来と同じ `testHome` の15指摘と `testUnpublishedMap` の4指摘。実機 VoiceOver（F-8）と正式地図上のコントラスト（F-10）は段階 B で確認する。[端末別の結果と再現条件](v1.0-integration-test.md)

### 2026-11-25 F-5 実装・F-2 改善・PR #226 `textClipped` 調査と 3 タブ／7 日失効反映後の再確認

3タブ再編（PR #237）・7日キャッシュ失効（PR #238）・経路プレビュー（PR #236）・手動出発地（PR #231）反映後の構成に対し、`iPhone 16e`（iOS 18.6）および `iPhone 17e`（iOS 27.0）でライト／ダーク × Large／AX5 を確認し、未反映だった A11y 決定事項と検出された崩れを修正しました。

- 単体試験（Scheme `Nexus` Debug、`iPhone 17e` iOS 27.0）：**662 件全件通過**（F-5 の `.inline` / `.large` 切替テストを含む）
- Release ビルド（Scheme `Nexus`、`generic/platform=iOS Simulator`）：**成功**
- XCUITest 監査（Scheme `Nexus Accessibility`、`iPhone 16e` iOS 18.6、Light / Large）：7件中 `testSearch`・`testGuidance` 系 3 件・`HomeSearchFlowTests`（3タブ確認＋インライン検索往復）が全通過。残る監査指摘は `testHome` 15件（F-1 `secondaryLabel` および下部カード見切れのコントラスト 13件、`.caption2` Dynamic Type 2件）・`testUnpublishedMap` 4件（F-1 `secondaryLabel` 1件、`NexusStatusView` Dynamic Type 2件、Map 単一行 `UITextField` の `textClipped` 1件）の計 19 件（修正前の 22 件・PR #226 時点の 39〜40 件から減少）。

#### 今回の修正・調査結果

| ID / 観点 | 対応・調査内容 | 確認結果 |
|---|---|---|
| F-5（AX1〜AX5 見出し `.inline`） | `EventListView` で `dynamicTypeSize.isAccessibilitySize` に応じて `.navigationBarTitleDisplayMode` を `.inline` / `.large` に切替（`EventListView.titleDisplayMode(for:)` と単体試験を追加） | iPhone 16e（iOS 18.6）・iPhone 17e（iOS 27.0）とも Large では `.large` 維持、AX5（ライト／ダーク）では `.inline` で「すべてのイベント」が末尾省略されず全文表示 |
| F-2（Map 地点詳細 AX5） | `SpotDetailCardView` で AX1〜AX5 時は保存版の有無にかかわらず見出し・保存版バナー・詳細・「出発地を選ぶ」を単一 `ScrollView` に収め、主操作「マップで見る」を固定。あわせて `SearchFieldView` の `@ScaledMetric` による空余白過拡大（AX5 で約 150pt→約 80pt）を抑え、`SpotEventSlotRow` の会場＋「経路」を AX1〜AX5 で縦積みに変更 | iPhone 16e（iOS 18.6）・iPhone 17e（iOS 27.0）のライト／ダーク・AX5 でスクロール表示域が従来の約 171pt から約 385pt へ拡大。末尾の中止理由・会場「経路」・固定「マップで見る」・「出発地を選ぶ」まで到達可能 |
| `MapRouteButtonLabel` 文字切れ | `MapRouteButtonLabel` の `.lineLimit(1)` により AX5 で「マップ…」と省略され `testHome` でも `textClipped` が出ていた問題を、AX1〜AX5 で折り返し許可（`.lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)`＋`.fixedSize(horizontal: false, vertical: true)`）に修正 | `testHome` の `textClipped` が 0 件になり、AX5 の地点詳細カードでも「マップで見る」が欠けずに表示 |
| PR #226 Map 検索欄 `textClipped` 調査 | `NexusStatusView` / `MapSurfaceStateView` に `.fixedSize(horizontal: false, vertical: true)` と `ViewThatFits` 調整を入れて地図未公開メッセージの `textClipped` を解消。残った Map 検索欄 `SwiftUI.UIKitTextField` の `textClipped` を A/B 検証（`surface`・`nexusFloatingSurface`・`accessibilitySortPriority(100)`・`axis: .vertical`）で切り分け | `ScrollView` 外に置かれた単一行 `SwiftUI.UIKitTextField` に対して Apple の `XCUIAccessibilityAudit` が発火する仕様と特定（`axis: .vertical` にすると `UITextView` になり警告は消えるが、`textField` 役割とキーボード「検索」確定挙動が損なわれる）。ライト／ダーク × Large／AX5 の実画面では「学科・施設・イベントを検索」／「検索」とも欠けずに表示されており、単一行 `TextField` を維持 |
| 3タブ（PR #237）・7日失効（PR #238）の AX5 確認 | `HomeSearchEntryView` は AX5 で `Capsule()` が縦長の楕円になるため `RoundedRectangle(cornerRadius: 20)` に切替＋虫眼鏡アイコンを `.font(.body)` に変更。`SavedHomeBannerView`（上下余白・`fixedSize`）と `HomeStatusView`（`fixedSize`）を `SavedContentBannerView` / `NexusStatusView` と整合 | Home 内インライン検索・保存版バナーともライト／ダーク × Large／AX5 で崩れ・文字切れなし。`testSearch` は Light / Large・Dark / AX5 ともに 0 件で通過 |

#### 残件と #87 への引き継ぎ（現行 3 タブ構成）

| ID | 現在の状態 | 残りの確認・判断 |
|---|---|---|
| F-1 | **決定・対応済み**（2026-11-24 決定：システム標準 `secondaryLabel` を継続使用、OS「コントラストを上げる」と自動連動） | なし（監査ツールの `secondaryLabel` 警告は HIG 準拠の許容事項） |
| F-2 | **改善・確認済み**（2026-11-25：AX5 スクロール域を拡大し、小幅端末ライト／ダークで到達確認済み） | #87 の実機確認で操作感を通し確認 |
| F-4 | **解消済み**（PR #237 の 3 タブ再編で「探す」タブの `Picker(.segmented)` を廃止し、44pt 以上のカテゴリチップへ移行） | なし |
| F-5 | **対応済み**（2026-11-25：`EventListView` で AX1〜AX5 時に `.inline` へ切替、単体試験＋iOS 18.6 / 27.0 確認済み） | なし |
| F-6 | **対応済み**（Home 帯は装飾として維持、Map 選択ピンは `CampusMapMarkers`＋`MapFocusedPinContrast` で 3:1 以上を確保し `AccessibilityContrastTests.testFocusedMapPinAndRingMeetAA` で検証済み） | 正式地図背景での目視確認は F-10 とあわせて実施 |
| F-8 | **要実機**（コード・単体試験・シミュレーター監査は完了） | [#87](https://github.com/m0o9l0v3/NexusMobile/issues/87) の TestFlight 実機ビルドで、**3タブ（ホーム／マップ／案内）**の選択、Home 内インライン検索の入力・絞り込み・履歴・キャンセル・タブ再タップ復帰、イベント一覧、地点詳細、Home カードの読み上げ順とフォーカス順を観点2の手順3に沿って確認する |
| F-10 | **要確認（正式地図データ待ち）**（検索欄・地点詳細の浮いたパネルは `regularMaterial` を使用） | 正式な地図データ反映後、明暗の異なる地図背景の上にパネルを重ねてライト／ダークで観点4を確認する |

### 2026-11-23 F-3・F-9 の修正と再確認

[PR #180](https://github.com/m0o9l0v3/NexusMobile/pull/180) の先行確認に続き、iPhone 17e（iOS 26.5）の DEBUG プレビューで確認しました。
標準 Scheme `Nexus` の単体試験は同じ端末で 588 件すべて通過しました（Xcode 27.2）。
iOS 27.0 の iPhone 17e でもライト／ダーク × Large／AX5 で案内文とカードの停止位置を確認し、単体試験 588 件が通過しました。

| ID | 修正 | 確認結果 |
|---|---|---|
| F-3 | 共通の検索欄をアクセシビリティ文字サイズで「検索」に短縮 | 探す・Map ともライト／ダーク × Large／AX5 で案内文を表示。ライト・AX5 で `2A` のキーボード確定、2A教室の表示、入力の消去を両画面で確認 |
| F-9 | アクセシビリティ文字サイズで Home の横スクロールをカードの位置に揃える | ライト／ダークの AX5 で先頭から最後まで4枚が表示領域の左端に揃い、最後のカードの中止理由と「詳細」が表示された。Large はライト／ダークともカードの途中で停止できた。プレビューで「詳細」と「マップで見る」を押し、地点が見つからない表示と経路未提供の表示まで確認した |

#### 再確認手順

1. Large／AX5 とライト／ダークを組み合わせ、表の方法で探すと Map の検索欄を開く。Large では「学科・施設・イベントを検索」、AX5 では文字が縮まず「検索」が欠けずに表示されることを確認する。
2. それぞれの検索欄で `2A` を入力し、キーボードの「検索」で確定して「2A教室」が出ることを確認する。「検索語を消去」で入力が消えることも確認する。VoiceOver の読み上げとフォーカス順は観点2の実機手順で確認する。
3. `-NexusPreviewData` で Home の「この後のイベント」へスクロールする。AX5 で短く左右にドラッグし、手を離すとカードの左端が表示領域の左端に揃うこと、最後の中止カードまで往復でき、下部の操作と中止理由が読めることを確認する。Large では途中位置に止められることを確認する。

#### #87 への引き継ぎ（2026-11-23 時点の履歴・現行は上の 2026-11-25 節を参照）

| ID | 現行コードで確認したこと | 残りの確認・判断 |
|---|---|---|
| F-1 | 補足表示はシステムの `.secondary` を使う。先行確認ではライトの白地で約 3.4:1。今回も探すのライト表示で淡い補足文字を確認した。単体試験の一部は `secondaryLabel` の RGB を不透明として比較している | 2026-11-24 決定により `secondaryLabel` 継続使用で確定 |
| F-2 | iPhone 17e（iOS 26.5）のライト・AX5 でイベント本文の見える範囲は高さ 171pt。本文をスクロールすると末尾の中止理由まで到達でき、下部の「経路を確認」は固定表示 | 2026-11-25 に AX5 スクロール域拡大を反映・再確認済み |
| F-4・F-5 | Large の種別絞り込みはシステムのセグメント、アクセシビリティ文字サイズではメニュー。iPhone 17e（iOS 26.5）のダーク・AX5 で一覧の見出しが「すべてのイ…」になる | F-4 は PR #237 の 3タブ再編で廃止、F-5 は 2026-11-25 に `.inline` 切替で対応済み |
| F-6 | Home の帯は装飾で、選択中の MapKit ピンには `EventAccent` と `OnAccent` の組み合わせが残る | `CampusMapMarkers` で 3:1 以上に対応済み（`testFocusedMapPinAndRingMeetAA`） |
| F-8 | 検索欄の読み上げ用ラベルは「検索語の入力」。実際の読み上げとフォーカス順は実機で確認する | [#87](https://github.com/m0o9l0v3/NexusMobile/issues/87) の TestFlight 実機ビルドで、3タブ（ホーム／マップ／案内）の選択、Home インライン検索・Map 検索、Home カードの操作順とイベント名の読み上げを観点2に沿って確認する |
| F-10 | 検索欄・地点詳細の浮いたパネルは `regularMaterial` を使う。今回の検索確認は地図未提供のプレビュー。地図の色を近似した単体試験は建物ラベルとピンを対象にしている | 正式な地図・データの版と表示箇所を記録し、明暗の異なる場所にパネルを重ねてライト／ダークで観点4を行う |

### 2026-11-14 SwiftUI 先行確認（#78 の最初の段階）

- 端末：iPhone 16e・iPhone 16（iOS 18.6）、iPhone 17e・iPhone 17（iOS 26.5・iOS 27.0）。それぞれライト・ダーク × Large・AX5。
- 試験：全 392 件が通過（新規 14 件を含む）。
- スクリーンショット：PR の本文に載せた（修正前後）。

| 観点 | 結果 | 備考 |
|---|---|---|
| 1 タップ領域 | 合格（指摘 F-4 を除く） | アプリ独自の操作はすべて 44pt 以上 |
| 2 VoiceOver | コードと試験で合格、**要実機** | シミュレーターで VoiceOver が動かないため、読み上げ順は #87 の実機確認で行う |
| 3 Dynamic Type | 修正後に合格（F-2・F-3・F-5 を除く） | 修正前は Home の次のイベント・カード・一覧の行が崩れていた |
| 4 コントラスト | 修正後に合格（F-1・F-6 を除く） | 修正前はダークのアクセント色・中止の赤・注意の橙が不足 |
| 5 Reduce Motion | 合格 | Ripple と地図の移動は `accessibilityReduceMotion` で止まる |

iOS 26.5・27.0 で追加で見たこと（直したものの後のビルドで確認）：
- 上の5つの観点の結果は iOS 18.6 と同じだった。iOS 26 以降で新しく崩れる画面はなかった。
- Home・すべてのイベントを AX5 で一番下までスクロールすると、最後の内容は浮いたタブバーの上で止まって読めた。
- タブバーの項目名は文字サイズに合わせて大きくならない。これはシステムの振る舞いで、長押しすると拡大表示される（HIG の Large Content Viewer）。
- iOS 26 以降のナビゲーションバーでは、戻るボタンが文字のない丸いボタンになる（VoiceOver では「戻る」と読む、要実機）。
- 地図の上のパネルは、地図のデータがないため後ろが無地の状態でしか見られていない（F-10）。

この段階で直したもの：

| 画面 | 問題 | 直し方 |
|---|---|---|
| 全体 | ダークのアクセント色の文字が暗い下地で 3.0〜3.7:1。ライトも `Surface`・`tintSurface` の上で 3.9〜4.3:1 | `AccentColor` をライト `#0B5ED7`（Web の `--primary`）、ダーク `#78AAFF`（`StatePressed` のダークと同じ青）にした |
| 選択中のチップ・開催中バッジ・主ボタン | ダークの明るいアクセント色の上の白文字が 2.3:1 になる | Asset `OnAccent`（ライト白・ダーク黒）を作り、`NexusTheme.onAccent` と `borderedProminent` の文字に使った |
| 中止の文字・バッジ | システムの赤はライトの白地で 3.6:1、赤地の白文字も 3.4〜3.6:1 | Asset `Cancelled`（ライト `#D70015`・ダーク `#FF6961`）にし、バッジの文字は `OnAccent` |
| 案内「困ったとき」 | システムの橙はライトの白地で 2.2:1 | Asset `CautionAccent`（ライト `#A84B00`・ダークはシステムの橙と同じ `#FF9F0A`） |
| Home 次のイベント | AX5 で横並びのまま1文字ずつ折り返し、場所が見えない | 大きな文字サイズでは時刻と内容を縦に積み、飾りの帯と矢印を出さない |
| Home この後のイベント | AX5 でカードが画面幅より広く、右側と「マップで見る」が切れる。LazyHStack が最初のカードの高さで並びの高さを決め、中止のカードの下が切れる | AX5 ではカードを横スクロールの表示幅にし、「詳細」「マップで見る」を縦に積む。並びを `HStack` にした（最大10件） |
| Home 開催日カード・この後のイベントの見出し | AX5 で「開催中」の文字が丸からはみ出す。見出しが細切れに折り返す | 大きな文字サイズでは縦に積む |
| すべてのイベント | AX5 で時刻の列の横で内容が1文字ずつ折り返す | 大きな文字サイズでは時刻と内容を縦に積む |
| Home のカード・一覧の行 | 「詳細」「マップで見る」が同じ名前で並び、どのイベントのものか分からない | イベント名を添えた名前にした（例「ドローン体験の詳細」） |
| Home 次のイベント | 読み上げに別の日付・終日などの文言とカテゴリがない | 見た目と同じ情報を読む |
| すべてのイベント | チップの列に付けた名前が、子のチップの読み上げを上書きするおそれがある | `accessibilityElement(children: .contain)` で、まとまりにだけ名前を付けた |

残った指摘（次の段階で扱う）：

| ID | 画面 | 問題 | 重さ | 提案 |
|---|---|---|---|---|
| F-1 | 全体 | システムの `secondaryLabel`（補足の文字）はライトの白地で約 3.4:1 で、本文の 4.5:1 に届かない。HIG のシステム色をそのまま使っている | 中 | **決定（2026-11-24 利用者決定）**：システムの `secondaryLabel` を継続使用する。HIG に準拠し、ユーザーが「コントラストを上げる」設定をオンにすれば自動で 7:1 以上に上がるため標準の振る舞いとして許容（[M1 v1.0 仕様決定記録](../decisions/M1-v1.0-spec-decisions.md)） |
| F-2 | Map 地点詳細 | AX5 でカードの中のスクロール域が2〜3行分しかなく、イベント欄を読むのに細かいスクロールが要る | 中 | 大きな文字サイズではシートで全画面に出す、または「経路を確認」をスクロールの中に入れる。Map の作業と合わせる |
| F-3 | 探す・Map の検索欄 | 入力欄の案内文（「学科・施設・イベントを検索」）が幅に合わせて縮み、AX5 で小さい文字になる（`UITextField` の縮小） | 低 | 大きな文字サイズでは案内文を短く（「検索」）する、または `axis: .vertical` を検討 |
| F-4 | 探す | 種別の絞り込み（`Picker(.segmented)`、標準の文字サイズ）は高さ約 32pt。システムの部品で HIG どおり | 低 | 変えない。大きな文字サイズではメニューに切り替わる |
| F-5 | すべてのイベント | AX5 でナビゲーションの大きい見出しが「すべてのイ…」と切れる（システムの振る舞い） | 低 | **決定（2026-11-24 利用者決定）**：アクセシビリティ文字サイズ（AX1〜AX5）時は見出しを `.inline` 表示に切り替えて文字切れを防ぐ（[M1 v1.0 仕様決定記録](../decisions/M1-v1.0-spec-decisions.md)） |
| F-6 | Home 次のイベント・Map のピン | `EventAccent`（ライト `#FF8D28`）は白地で 2.3:1。次のイベントの帯は飾り（読み上げ対象外、情報は文字にある）。地図の選択中ピンの白い記号も 2.3:1 | 低 | **決定（2026-11-24 利用者決定）**：Home の帯は装飾として現状維持。Map の選択中ピンの白抜き記号は枠線や明度調整でグラフィック基準 3:1 以上を確保する（[M1 v1.0 仕様決定記録](../decisions/M1-v1.0-spec-decisions.md)） |
| F-7 | 全体 | UI 試験のターゲットがなく、`performAccessibilityAudit()` を使えない | 低 | 対応済み。[専用 Scheme での監査手順](#f-7-主要画面の-xcuitest任意実行)を参照 |
| F-8 | 全体 | VoiceOver の読み上げ順・フォーカス順はシミュレーターで確かめられない | 要実機 | #87 の TestFlight 実機確認で観点2の手順3を行う |
| F-9 | Home | AX5 ではカードが表示幅いっぱいになるが、横スクロールは止まる位置が決まっていない | 低 | 大きな文字サイズだけ `scrollTargetBehavior(.viewAligned)` を検討（標準サイズの操作感は変えない） |
| F-10 | Map（iOS 26 以降） | 地図の上の半透明パネル（検索欄・地点詳細）の文字のコントラストは、後ろの地図の色で変わる。地図のデータ待ちのため、無地の後ろでしか確かめていない | 要確認 | 地図を表示できるようになったら、明るい地図・暗い地図の上で観点4を行う |

### 2026-11-23 F-7 専用 Scheme の初回監査

Apple M4・Xcode 27.2（27B52）、起動済み iPhone 16e シミュレーター（iOS 18.6）、新規 DerivedData、並列実行なしで1回計測しました。実時間は `build-for-testing` が 43.55 秒、`test-without-building` が 104.68 秒（うち XCTest の4件が 47.29 秒）です。GitHub Actions の実行時間は未計測です。

4画面とも対象要素の表示を確認し、監査で失敗しました。XCTest の指摘は Home 16 件・探す 10 件・案内 8 件・地図未公開 4 件です。内訳はコントラスト 26 件、Dynamic Type 10 件、探す・Map の検索欄の文字切れ各 1 件です。同じ原因による指摘を含む可能性があり、各要素の判定には上の観点別手順を使います。

独立確認では iPhone 16（iOS 18.6）で4画面すべての対象要素が表示され、監査は40件を検出しました（コントラスト28件、Dynamic Type 10件、文字切れ2件）。起動済み端末に対する新規ビルドは61.37秒、試験コマンドは72.66秒でした。標準 Scheme `Nexus` では `NexusTests` の588件が通過しました。

初回監査は [PR #225](https://github.com/m0o9l0v3/NexusMobile/pull/225) の F-3・F-9 を含まないビルドで行いました。両方の PR の差分を組み合わせたビルドで、iPhone 16（iOS 18.6）を使って追試しました。

- 4画面で39件を検出しました（コントラスト28件、Dynamic Type 10件、文字切れ1件）。この実行では探すの文字切れは検出されず、Map の従来の案内文に対する検出が残りました。
- ライト／ダーク × Large／AX5 の目視では、探す・Map の案内文は欠けずに表示されました。Map のダーク・AX5 だけを再監査すると「検索」に対する `textClipped` が1件残りました。目視と監査結果が異なる原因は未確認です。

[#87](https://github.com/m0o9l0v3/NexusMobile/issues/87) では配布対象と同じコミットの DEBUG ビルドで監査を再実行し、残った Map の指摘を確認します。TestFlight では観点2の実機 VoiceOver と正式な地図上での観点4を確認します。
