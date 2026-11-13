# デザインルール

この文書は Nexus 全体（iOS アプリ・公開サイト `web/`・管理ポータル）のデザインルールです。余白・角丸・影・タイポなどの視覚スタイルルールは新規UI（公開サイト `web/` を含む）にも引き続き適用します。「UI表示ルール」節は、参加者向け PWA プロトタイプ（Home のゲストチェックイン）を前提にした旧仕様であり、チェックイン機能は [Nexus v1.0 スコープ定義](v1.0-scope.md) の対象外です。公開サイトの画面構成・CTA・情報設計は [GitHub Issue #131](https://github.com/m0o9l0v3/NexusMobile/issues/131) の情報設計に従い、本節のチェックイン前提のCTAパターンをそのまま踏襲しないでください。

## デザインルール（余白 / 角丸 / 影 / 文字）
- 余白: コンテンツ間 `16px`、セクション `20px`、ボトムナビのタップ領域 `44px+` を確保
- 角丸: 通常 `16px`、主要カード `20px`、ヒーロー/ボトムナビ外枠 `22-28px`
- 影 (Material 3 風 Elevation):
  - `--elev-1`: 小さな面（リスト/ボタン）
  - `--elev-2`: 主要ボタンやカード
  - `--elev-3` / `--shadow-card`: ヒーローや大きなカード
- タイポ: Noto Sans JP + Inter、数字は `tabular-nums`。見出しは太め、補助テキストは `--muted`（iOS アプリは下の「iOS アプリ」節のとおり SF Pro）
- 背景: 淡い空色グラデーション（`--bg`, `--bg-grad-1`）、カードは白＋弱い影
- モーション: `prefers-reduced-motion: reduce` では transform/animation を停止し、色変化のみで状態を表現

## iOS アプリ（`apps/nexus-ios/` とその Figma）

2026-11-14 オーナー決定。

- **上の Nexus 全体のルールに従う。** そのうえで、本書に書いていないことは Apple の [Human Interface Guidelines（iOS）](https://developer.apple.com/jp/design/human-interface-guidelines/designing-for-ios) に従う（テキストスタイルと Dynamic Type、システムの部品、Liquid Glass、VoiceOver など）。
- **フォントは SF Pro**（システムフォント）。日本語はシステムの和文フォントに任せ、フォントを同梱しない。Figma でも SF Pro を使う。
- 状態は色だけで示さず、文字やアイコンを添える（例：中止）。
- 視差効果を減らす設定（Reduce Motion）では、上の「モーション」と同じく動きを止めて色の変化で示す。

### 全体のルールと iOS で扱いが違う点（2026-11-14 決定）

次の3点は、現在の iOS の実装（および Home v1.0 の Figma 下書き、[home-v1.0-draft.md](design/home-v1.0-draft.md)）が全体のルールと合っていなかった。オーナーが次のとおり決めた。

| 項目 | 全体のルール | iOS での扱い |
|---|---|---|
| 背景 | 淡い空色グラデーション、カードは白＋弱い影 | **今のまま**（`Color(.systemBackground)` と `NexusTheme` のカード）。iOS の例外とする |
| 影・押下 | Material 3 風 Elevation（3段階）、State layer、Ripple | **全体のルールに揃える** |
| テーマ | ライトテーマ固定 | **ライトとダークの両方に対応する**。iOS の例外とする |

- Elevation の3段階・State layer の色は、Web の値（`web/src/styles/theme.css` の `--elev-1/2/3`、`--state-pressed`）を基に `NexusTheme` に持たせる。ダークテーマでは影が見えにくいため、見え方を確かめて値を分ける。
- Ripple は「視差効果を減らす」設定では出さず、State layer（押下時の重ね色）だけで示す。
- 色はダークテーマに追従するもの（システムの色、Asset Catalog の Any / Dark の色）を使い、白や黒を直接書かない。
- システムの部品（タブバー・ナビゲーションバー・Liquid Glass）の見た目は変えない。
- 移行は既存画面をまとめて揃える1つの変更で行い、新しい画面はその後の `NexusTheme` を使う。

## UI表示ルール（State-driven UI、旧参加者向け PWA 仕様・v1.0 対象外）
- **Primary**: 画面の主目的は1つに絞り、Homeのみで主要CTA（チェックイン）を提示
- **Secondary/Tertiary**: Spot / Nearby / 詳細は情報閲覧を主目的にし、CTAは控えめに配置
- **ゲストチェックイン**:
  - Home かつ **未チェックイン時のみ**ヒーローCTAを表示
  - チェックイン後は小さなステータス表示に置き換え、常時CTAは表示しない
- **常時表示**: グローバルナビ（トップバー + ボトムナビ）のみ
- **Contextual CTA**: 必要な場面でだけボタンを出し、補助情報は要約または二次画面へ退避
