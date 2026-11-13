# デザインルール

## 適用範囲

| 対象 | 正とするルール |
|---|---|
| **iOS アプリ（`apps/nexus-ios/`）と、その Figma** | **Apple の [Human Interface Guidelines（iOS）](https://developer.apple.com/jp/design/human-interface-guidelines/designing-for-ios)**。本書の「iOS アプリ」節は、HIG の上でこのプロジェクトが決めたことだけを書く |
| 公開サイト（`web/`）・管理ポータル（`apps/admin-web/`） | 本書の「Web のデザインルール」節 |

（2026-11-14 オーナー決定。それまで iOS にも Web と同じ「Noto Sans JP + Inter、空色グラデーション背景」を当てる書き方になっていたが、iOS の実装は SF Pro と標準の背景で作られており食い違っていた。Home v1.0 の Figma 下書き（[home-v1.0-draft.md](design/home-v1.0-draft.md)）で指摘された。）

## iOS アプリ

基本は HIG に従う。HIG と本節が食い違う場合は HIG を正とし、本節を直す。

- **フォント**：**SF Pro**（システムフォント）。日本語は SF Pro と組み合わさるシステムの和文フォントに任せ、フォントを同梱しない。Figma でも SF Pro を使う。
- **文字の大きさ**：SwiftUI のテキストスタイル（`.body`、`.caption` など）を使い、Dynamic Type に追従させる。固定の大きさは、アイコンなど文字でないものに限る。
- **色**：システムの色（`Color(.systemBackground)`、`.primary`、`.secondary`、`Color.accentColor` など）と `NexusTheme` を使う。状態は色だけで示さず、文字やアイコンを添える（例：中止）。
- **タップ領域**：44×44pt 以上。
- **Liquid Glass**：タブバー・ナビゲーションバー・戻るボタンなど、システムの部品が持つものだけに使い、中身のカードには使わない（Home v1.0 の Figma 下書きと同じ）。
- **1画面1主目的**：Home は各機能への入口にとどめ、長いフィードにしない。
- **アクセシビリティ**：VoiceOver の読み上げ文、Dynamic Type、視差効果を減らす設定に対応する。

## Web のデザインルール

この節は公開サイト `web/` と管理ポータルの視覚スタイルに適用する。iOS アプリには適用しない（上の「適用範囲」）。「UI表示ルール」節は、参加者向け PWA プロトタイプ（Home のゲストチェックイン）を前提にした旧仕様であり、チェックイン機能は [Nexus v1.0 スコープ定義](v1.0-scope.md) の対象外です。公開サイトの画面構成・CTA・情報設計は [GitHub Issue #131](https://github.com/m0o9l0v3/NexusMobile/issues/131) の情報設計に従い、本節のチェックイン前提のCTAパターンをそのまま踏襲しないでください。

### 余白 / 角丸 / 影 / 文字
- 余白: コンテンツ間 `16px`、セクション `20px`、ボトムナビのタップ領域 `44px+` を確保
- 角丸: 通常 `16px`、主要カード `20px`、ヒーロー/ボトムナビ外枠 `22-28px`
- 影 (Material 3 風 Elevation):
  - `--elev-1`: 小さな面（リスト/ボタン）
  - `--elev-2`: 主要ボタンやカード
  - `--elev-3` / `--shadow-card`: ヒーローや大きなカード
- タイポ: Noto Sans JP + Inter、数字は `tabular-nums`。見出しは太め、補助テキストは `--muted`
- 背景: 淡い空色グラデーション（`--bg`, `--bg-grad-1`）、カードは白＋弱い影
- モーション: `prefers-reduced-motion: reduce` では transform/animation を停止し、色変化のみで状態を表現

### UI表示ルール（State-driven UI、旧参加者向け PWA 仕様・v1.0 対象外）
- **Primary**: 画面の主目的は1つに絞り、Homeのみで主要CTA（チェックイン）を提示
- **Secondary/Tertiary**: Spot / Nearby / 詳細は情報閲覧を主目的にし、CTAは控えめに配置
- **ゲストチェックイン**:
  - Home かつ **未チェックイン時のみ**ヒーローCTAを表示
  - チェックイン後は小さなステータス表示に置き換え、常時CTAは表示しない
- **常時表示**: グローバルナビ（トップバー + ボトムナビ）のみ
- **Contextual CTA**: 必要な場面でだけボタンを出し、補助情報は要約または二次画面へ退避
