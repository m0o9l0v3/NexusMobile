# 現在地UI 下部バー連結 案（#25 理由の表示・#29 Map の現在地）

- 状態: **案B に決定**（2026-11-14、オーナー）。実装は `feature/ios-location-sheet-attached`。
- 作成: 2026-11-14
- 前提: [デザインルール](../design-rules.md) → Apple HIG。iOS は SF Pro、`systemBackground`、ライト・ダーク両対応。
- 対象: PR #184（#25 権限フロー）の `LocationPermissionStatusView` と `.locationPermissionFlow`、PR #185（#29 現在地）の Map 上の表示。

## 1. いまの問題と原因

**再現**（iPhone 17 Pro / iOS 26.5、`-NexusMapKitCheck -NexusPreviewScreen map -NexusLocationFixture <reducedAccuracy|failure>` で現在地ボタンを押す）：
理由の表示（精度不足・取得不能など）が出ると、2 つ目のボタンの途中で面がまっすぐ切れ、下の角丸も影もないまま、タブバーの約 8pt 上で終わる。ライト・ダークとも同じ。

**原因**（`LocationPermissionExplanationView.swift` の `LocationPermissionFlowModifier`）：

1. 理由の表示は `.safeAreaInset(edge: .bottom)` に入れ、`ViewThatFits { panel; ScrollView { panel } }` の高さを `containerHeight * 0.6` で抑えている。
2. `containerHeight` は `.onGeometryChange` で `content`（Map）の高さを測るが、`.safeAreaInset` を付けると Map の高さは理由の表示の分だけ縮む。表示が出る → 上限が下がる → … を繰り返し、上限は約 `0.375 × Map の高さ`（実測で約 267pt）に落ち着く。
3. 中身（約 300pt）がこの上限に収まらないので `ViewThatFits` が ScrollView 版を選び、ScrollView が面（`nexusCard` の角丸・影を含む）を四角く切り取る。
4. 面はタブバーから 8pt 離れて浮いているので、切れた下端がそのまま見える。

AX サイズでは本当に 6 割を超えるのでスクロールが要るが、標準サイズで切れるのは 2. の測り方の問題。

**対象外**：説明シート（`.sheet` + `.medium`）はシステムのシートでタブバーごと覆い、切れない。構外の知らせ（`OffCampusNoticeView`）は検索の下（上側）にあり、下から出ない。

スクリーンショット（直す前・直した後）は assets 専用ブランチ `pr-assets/ios-location-sheet-attached`（マージしない）。

## 2. Figma

ファイル `WJqC7X5TuTvqTPnn40JIrV`、新しいページ「**v1.0 | 現在地UI 下部バー連結 案｜2026-11**」（[2808:1520](https://www.figma.com/design/WJqC7X5TuTvqTPnn40JIrV/?node-id=2808-1520)）。既存のフレームは変更・移動していない（タブバーとステータスバーはページ07 から複製して使った）。

### 案A｜下端まで伸びる面（タブバーが面の上に乗る）

理由の表示を、画面の下端まで伸びる 1 枚の面にする。上の 2 つの角だけ 28。タブバー（システムの Liquid Glass）は面の上に乗り、面の色がガラス越しに見えるので、タブバーから生えて見える。中身はタブバーの上端から 16 空けて終える。iOS 18 の不透明なタブバーでも、面がバーの下に続くので切れ目が出ない。

| 状態 | Light | Dark |
|---|---|---|
| 拒否 | [2810:1514](https://www.figma.com/design/WJqC7X5TuTvqTPnn40JIrV/?node-id=2810-1514) | [2810:1790](https://www.figma.com/design/WJqC7X5TuTvqTPnn40JIrV/?node-id=2810-1790) |
| 取得不能 | [2810:1608](https://www.figma.com/design/WJqC7X5TuTvqTPnn40JIrV/?node-id=2810-1608) | [2810:1876](https://www.figma.com/design/WJqC7X5TuTvqTPnn40JIrV/?node-id=2810-1876) |
| 精度不足 | [2810:1699](https://www.figma.com/design/WJqC7X5TuTvqTPnn40JIrV/?node-id=2810-1699) | [2810:1962](https://www.figma.com/design/WJqC7X5TuTvqTPnn40JIrV/?node-id=2810-1962) |
| 精度不足・AX3 | [2810:2048](https://www.figma.com/design/WJqC7X5TuTvqTPnn40JIrV/?node-id=2810-2048) | |

SwiftUI：`UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28)` を `.ignoresSafeArea(edges: .bottom)` の背景にし、中身はセーフエリアの内側に置く。iOS 18 から同じコード。

### 案B｜浮いたシートがタブバーを包む（iOS 26 の浮いたシートの形）— **採用**

左右と下を 8 空けた浮いた面にし、タブバーを面の内側に収める。上の角 28、下の角は画面の角に沿う（同心）。iOS 26 の地図アプリなどの浮いたシート、および説明シートと同じ形になる。iOS 18 では面の下端がバーに隠れ、案A とほぼ同じ見た目。

| 状態 | Light | Dark |
|---|---|---|
| 拒否 | [2812:1710](https://www.figma.com/design/WJqC7X5TuTvqTPnn40JIrV/?node-id=2812-1710) | [2812:1986](https://www.figma.com/design/WJqC7X5TuTvqTPnn40JIrV/?node-id=2812-1986) |
| 取得不能 | [2812:1804](https://www.figma.com/design/WJqC7X5TuTvqTPnn40JIrV/?node-id=2812-1804) | [2812:2077](https://www.figma.com/design/WJqC7X5TuTvqTPnn40JIrV/?node-id=2812-2077) |
| 精度不足 | [2812:1895](https://www.figma.com/design/WJqC7X5TuTvqTPnn40JIrV/?node-id=2812-1895) | [2812:2168](https://www.figma.com/design/WJqC7X5TuTvqTPnn40JIrV/?node-id=2812-2168) |
| 精度不足・AX3 | [2812:2259](https://www.figma.com/design/WJqC7X5TuTvqTPnn40JIrV/?node-id=2812-2259) | |

SwiftUI：iOS 26 は `ConcentricRectangle`（画面の角に沿う）、iOS 18 は `UnevenRoundedRectangle`（下の角は固定値）。OS で分岐が 1 か所増える。

### 案C｜タブバーの付属バー（`tabViewBottomAccessory`）＋詳細はシート

タブバーのすぐ上に、システムが描く付属バー（Liquid Glass のカプセル）を出し、見出しだけを 1 行で表示する。押すと詳細とボタンをシートで出す。タブバーにくっつく形を OS が保証する唯一の方法。

| 状態 | Light | Dark |
|---|---|---|
| 拒否（付属バー） | [2813:1926](https://www.figma.com/design/WJqC7X5TuTvqTPnn40JIrV/?node-id=2813-1926) | [2813:2160](https://www.figma.com/design/WJqC7X5TuTvqTPnn40JIrV/?node-id=2813-2160) |
| 取得不能（付属バー） | [2813:2004](https://www.figma.com/design/WJqC7X5TuTvqTPnn40JIrV/?node-id=2813-2004) | [2813:2238](https://www.figma.com/design/WJqC7X5TuTvqTPnn40JIrV/?node-id=2813-2238) |
| 精度不足（付属バー） | [2813:2082](https://www.figma.com/design/WJqC7X5TuTvqTPnn40JIrV/?node-id=2813-2082) | [2813:2316](https://www.figma.com/design/WJqC7X5TuTvqTPnn40JIrV/?node-id=2813-2316) |
| 精度不足（詳細シート） | [2813:2394](https://www.figma.com/design/WJqC7X5TuTvqTPnn40JIrV/?node-id=2813-2394) | [2813:2489](https://www.figma.com/design/WJqC7X5TuTvqTPnn40JIrV/?node-id=2813-2489) |
| 詳細シート・AX3 | [2813:2584](https://www.figma.com/design/WJqC7X5TuTvqTPnn40JIrV/?node-id=2813-2584) | |

制約：(1) `tabViewBottomAccessory` は iOS 26 以上（iOS 18 は自前のカプセルで代用）。(2) 付属バーは TabView 全体に付くので、Map 以外のタブで消す仕組みが要る（`isEnabled:` は iOS 26.1）。(3) 操作が 1 回増える（ボタンまで 2 タップ）。(4) 付属バーの高さは OS が決めるため、AX サイズでは見出しが省略されうる（要検証）。

### 共通｜説明シート（どの案でも変えない）

[Light 2814:2094](https://www.figma.com/design/WJqC7X5TuTvqTPnn40JIrV/?node-id=2814-2094)／[Dark 2814:2172](https://www.figma.com/design/WJqC7X5TuTvqTPnn40JIrV/?node-id=2814-2172)

### 部品・色（ページ内）

- `LocationDraft/ActionButton`（Style = Primary / Secondary、[2808:1535](https://www.figma.com/design/WJqC7X5TuTvqTPnn40JIrV/?node-id=2808-1535)）
- `LocationDraft/StatusHeader`（Size = Default / AX、[2808:1552](https://www.figma.com/design/WJqC7X5TuTvqTPnn40JIrV/?node-id=2808-1552)）
- 変数 `Nexus/v1.0/LocationDraft-2026-11`（Light / Dark）：accent（AccentColor #0B5ED7 / #78AAFF）、onAccent、cautionAccent、accentSoft、panelSurface、cardSurface、border。既存の `Review-20260908/Semantic/tint` は旧値 #1E6EF4 のままなので、コードに合わせた色を下書き用に別に置いた（既存の変数は変更していない）。

## 3. どの案でも直すこと（実装時）

- 高さの上限は、理由の表示を差し引く前の高さで決める（`safeAreaInset` の外側で測る）。標準サイズではスクロールにしない。
- AX サイズで上限を超えるときだけ面の中でスクロールし、下端を少しぼかして続きがあることを示す。面そのものは切らない。
- `AccessibilityContrastTests` に新しい下地（面の色）の組み合わせを足す。

## 4. 比較

| | A 下端まで伸びる面 | B 浮いたシート | C 付属バー＋シート |
|---|---|---|---|
| タブバーとのつながり | 面がバーの下に続く | バーが面にはまる | OS がつなげる |
| iOS 18 | 同じコード・同じ見た目 | 角の形だけ分岐 | 自前で代用（見た目が変わる） |
| 操作の数 | 1 タップでボタン | 1 タップでボタン | 2 タップ |
| 地図を隠す量 | 中 | 中 | 小（詳細を開くまで） |
| 実装の大きさ | 小 | 小〜中 | 中〜大 |

## 5. 実装（案B）

- `NexusAttachedSheetBackground`（`NexusAvailabilityShims.swift`）：面の形と色。iOS 26 は `ConcentricRectangle`（上 `.fixed(28)`、下 `.concentric(minimum: .fixed(28))`）、iOS 18 は角丸 28 の四角。塗りは `NexusTheme.cardSurface`、枠線 `NexusTheme.border`、影 `.level2`。
- `LocationStatusSheet`（`LocationPermissionExplanationView.swift`）：中身はタブバーの上（セーフエリアの内側）に置き、面だけを `.ignoresSafeArea(edges: .bottom)` でタブバーの下へ伸ばす。左右と下の余白 8（`NexusTheme.attachedSheetMargin`）、中身の余白は上 20・左右 20・下 16（`LocationStatusSheetLayout`）。
- 高さの上限は `.safeAreaInset` の外側で測る。`.frame(maxHeight:)` は上限まで広がるため、`CappedHeightLayout` で「上限までを提案し、子の高さを使う」。AX サイズで超えたときだけ ScrollView（表示時にスクロールバーを一度出す）。
- `LocationPermissionStatusView` に `chrome`（`.card` / `.plain`）を足した。シートの中では `.plain`（カードの枠なし）。#31 などで単独に置くときは今までどおり `.card`。
- 確認：iPhone 17 Pro / iOS 26.5（ライト・ダーク・AX3）、iPhone 16 Pro / iOS 18.6（ライト）。

### 残り（デザイン担当へ）
- Figma の案B のフレームを、ページ07 の部品・変数に合わせて仕上げる（ここでは下書き用の `LocationDraft/*` 部品と `Nexus/v1.0/LocationDraft-2026-11` 変数を使った）。
- 既存の `Review-20260908/Semantic/tint` は旧値 #1E6EF4。コードの AccentColor（#0B5ED7 / #78AAFF）に合わせるかの判断（`figma-handoff-2026-11.md` T-3）。
- シートが出ている間は、地図の左下の「マップ」「法律に基づく情報」がシートに隠れる（Apple のマップのシートと同じ）。気になる場合は地図の表示位置を調整する。
