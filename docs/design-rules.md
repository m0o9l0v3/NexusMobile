## デザインルール（余白 / 角丸 / 影 / 文字）
- 余白: コンテンツ間 `16px`、セクション `20px`、ボトムナビのタップ領域 `44px+` を確保
- 角丸: 通常 `16px`、主要カード `20px`、ヒーロー/ボトムナビ外枠 `22-28px`
- 影 (Material 3 風 Elevation):
  - `--elev-1`: 小さな面（リスト/ボタン）
  - `--elev-2`: 主要ボタンやカード
  - `--elev-3` / `--shadow-card`: ヒーローや大きなカード
- タイポ: Noto Sans JP + Inter、数字は `tabular-nums`。見出しは太め、補助テキストは `--muted`
- 背景: 淡い空色グラデーション（`--bg`, `--bg-grad-1`）、カードは白＋弱い影
- モーション: `prefers-reduced-motion: reduce` では transform/animation を停止し、色変化のみで状態を表現

## UI表示ルール（State-driven UI）
- **Primary**: 画面の主目的は1つに絞り、Homeのみで主要CTA（チェックイン）を提示
- **Secondary/Tertiary**: Spot / Nearby / 詳細は情報閲覧を主目的にし、CTAは控えめに配置
- **ゲストチェックイン**:
  - Home かつ **未チェックイン時のみ**ヒーローCTAを表示
  - チェックイン後は小さなステータス表示に置き換え、常時CTAは表示しない
- **常時表示**: グローバルナビ（トップバー + ボトムナビ）のみ
- **Contextual CTA**: 必要な場面でだけボタンを出し、補助情報は要約または二次画面へ退避
