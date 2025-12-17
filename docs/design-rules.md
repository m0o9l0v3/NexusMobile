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
