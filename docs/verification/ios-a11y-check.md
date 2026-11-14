# iOS アクセシビリティ確認手順（#78）

[#78](https://github.com/m0o9l0v3/NexusMobile/issues/78)（E9-5）の観点を、何度でも同じ手順で確かめられるようにまとめた文書です。
対象は `apps/nexus-ios/` の SwiftUI 画面です。デザインの基準は [`docs/design-rules.md`](../design-rules.md)（書いていないことは Apple HIG）です。

#78 の進め方は「SwiftUI で先行確認 → #87 の統合試験・TestFlight 実機確認 → #30 の整理後に影響を再確認」です。
この文書の手順は、どの段階でもそのまま使います。段階ごとの結果は末尾の「実施記録」に追記します。

## 1. 対象と環境

### 画面

| 画面 | 開き方（DEBUG ビルド） | 見る状態 |
|---|---|---|
| Home | `-NexusPreviewData` | 開催日カード、案内ショートカット、次のイベント、この後のイベント（中止のカードを含む。横にスクロールして最後のカード） |
| すべてのイベント | Home の「すべて見る」 | カテゴリの絞り込み、中止の行 |
| Map 地点詳細（イベント欄） | `-NexusPreviewData -NexusPreviewScreen eventDetail` | 枠3件（うち1件が中止） |
| 案内トップ | `-NexusPreviewData -NexusPreviewScreen guidance` | 本日のご案内、よく使う案内、困ったとき |
| 案内の記事 | `-NexusPreviewData -NexusPreviewScreen guidanceStandard`（ほか `guidanceHelp` / `guidanceAccess` / `guidanceFAQ` / `guidanceRelatedPlace`） | 見出し、更新状況、関連する場所 |
| 案内の空の状態 | 引数なし（同梱の原稿が空のとき）＋ `-NexusPreviewScreen guidance` | 「案内の原稿はまだありません」 |
| 探す | `-NexusPreviewData -NexusPreviewScreen search` | 検索欄、種別の絞り込み、結果の行 |

Map の地図・経路は調査データ待ちのため、Map の本確認は Map の作業の後に行います（#78 は閉じない）。

### 端末と設定

- 小さい端末：iPhone 16e（または iPhone SE 第3世代）
- 標準の端末：iPhone 16
- それぞれ **ライト・ダーク** × **文字サイズ 標準（Large）・最大（AX5）** の4通り

シミュレーターの設定は次のコマンドで切り替えます。

```bash
xcrun simctl ui <UDID> appearance light            # dark
xcrun simctl ui <UDID> content_size large          # accessibility-extra-extra-extra-large
xcrun simctl launch <UDID> dev.nexusapp.mobile -NexusPreviewData -NexusPreviewScreen eventDetail
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

自動にしていないもの：

- **XCUITest の `performAccessibilityAudit()`**：UI 試験のターゲットがまだないため使っていません（下の指摘 F-7）。
- **VoiceOver の実際の読み上げ・フォーカス順**：シミュレーターでは VoiceOver が動かないため、実機で確かめます（観点2の手順）。

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

### 観点5 視差効果を減らす（Reduce Motion）

手順：
1. コードで、動きを出す処理（`withAnimation`、`.animation`、`scaleEffect`、`.transition`）を検索し、`accessibilityReduceMotion` で止めているかを確かめる。
2. 実機またはシミュレーターで「設定 > アクセシビリティ > 動作 > 視差効果を減らす」をオンにし、カード・行・チップを長めに押す。

判定：
- 合格：Ripple（広がる円）が出ず、押下は State layer（重ね色）の色の変化だけ。地図の移動は動きなしで切り替わる。
- 不合格：Reduce Motion でも拡大・移動の動きが出る。

## 4. 実施記録

### 2026-11-14 SwiftUI 先行確認（#78 の最初の段階）

- 端末：iPhone 16e（iOS 18.6、小さい端末）、iPhone 16（iOS 18.6、標準）。ライト・ダーク × Large・AX5。
- 試験：全 392 件が通過（新規 14 件を含む）。
- スクリーンショット：PR の本文に載せた（修正前後）。

| 観点 | 結果 | 備考 |
|---|---|---|
| 1 タップ領域 | 合格（指摘 F-4 を除く） | アプリ独自の操作はすべて 44pt 以上 |
| 2 VoiceOver | コードと試験で合格、**要実機** | シミュレーターで VoiceOver が動かないため、読み上げ順は #87 の実機確認で行う |
| 3 Dynamic Type | 修正後に合格（F-2・F-3・F-5 を除く） | 修正前は Home の次のイベント・カード・一覧の行が崩れていた |
| 4 コントラスト | 修正後に合格（F-1・F-6 を除く） | 修正前はダークのアクセント色・中止の赤・注意の橙が不足 |
| 5 Reduce Motion | 合格 | Ripple と地図の移動は `accessibilityReduceMotion` で止まる |

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
| F-1 | 全体 | システムの `secondaryLabel`（補足の文字）はライトの白地で約 3.4:1 で、本文の 4.5:1 に届かない。HIG のシステム色をそのまま使っている | 中 | システム色を使い続ける（「コントラストを上げる」設定で上がる）か、`NexusTheme` に濃い補足色を作るかをオーナーが決める |
| F-2 | Map 地点詳細 | AX5 でカードの中のスクロール域が2〜3行分しかなく、イベント欄を読むのに細かいスクロールが要る | 中 | 大きな文字サイズではシートで全画面に出す、または「経路を確認」をスクロールの中に入れる。Map の作業と合わせる |
| F-3 | 探す・Map の検索欄 | 入力欄の案内文（「学科・施設・イベントを検索」）が幅に合わせて縮み、AX5 で小さい文字になる（`UITextField` の縮小） | 低 | 大きな文字サイズでは案内文を短く（「検索」）する、または `axis: .vertical` を検討 |
| F-4 | 探す | 種別の絞り込み（`Picker(.segmented)`、標準の文字サイズ）は高さ約 32pt。システムの部品で HIG どおり | 低 | 変えない。大きな文字サイズではメニューに切り替わる |
| F-5 | すべてのイベント | AX5 でナビゲーションの大きい見出しが「すべてのイ…」と切れる（システムの振る舞い） | 低 | 大きな文字サイズでは `.inline` の見出しにする |
| F-6 | Home 次のイベント・Map のピン | `EventAccent`（ライト `#FF8D28`）は白地で 2.3:1。次のイベントの帯は飾り（読み上げ対象外、情報は文字にある）。地図の選択中ピンの白い記号も 2.3:1 | 低 | 帯は飾りとして扱う。ピンは Map の作業で色を見直す |
| F-7 | 全体 | UI 試験のターゲットがなく、`performAccessibilityAudit()` を使えない | 低 | UI 試験のターゲットを別の PR で足し、主要画面で監査を回す |
| F-8 | 全体 | VoiceOver の読み上げ順・フォーカス順はシミュレーターで確かめられない | 要実機 | #87 の TestFlight 実機確認で観点2の手順3を行う |
| F-9 | Home | AX5 ではカードが表示幅いっぱいになるが、横スクロールは止まる位置が決まっていない | 低 | 大きな文字サイズだけ `scrollTargetBehavior(.viewAligned)` を検討（標準サイズの操作感は変えない） |
