# Nexus 公開サイト（`web/`）

アプリ（iOS）の告知、開発状況、サーバー状況、開発に伴う技術説明を掲載するサイトです（[#131](https://github.com/m0o9l0v3/NexusMobile/issues/131)）。参加者向けアプリ機能は iOS アプリだけが持ち、このサイトは代替機能を持ちません。

ページはトップ＋3ページのマルチページ構成です（ルーター用のライブラリは使いません）。方針と決定は [`docs/overview.md`](../docs/overview.md)、見た目のルールは [`docs/design-rules.md`](../docs/design-rules.md) の「公開サイト（`web/`）」節にあります。

| ページ | 入口の HTML | 画面のコード |
|---|---|---|
| トップ（アプリの告知） | `index.html` | `src/pages/top.tsx` |
| 開発状況 | `development/index.html` | `src/pages/development.tsx` |
| サーバー状況 | `status/index.html` | `src/pages/status.tsx` |
| 技術説明 | `tech/index.html` | `src/pages/tech.tsx` |

- 共通の枠（ヘッダー・スマホのメニュー・フッター）：`src/components/Layout.tsx`
- 手で書くお知らせ・開発状況：`content/`（書き方は [`content/README.md`](content/README.md)）
- アプリの画面画像：`public/app-shots/hero-light.png`・`hero-dark.png`（承認後に置く。無い間はトップに画像を出さない）

## 開発

```bash
npm install
VITE_API_BASE_URL=https://... npm run dev   # http://localhost:5176
npm run typecheck
npm run build      # dist/ に出力（git では追跡しない）
```
