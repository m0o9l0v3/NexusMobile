# Nexus 公開サイト（`web/`）

アプリ（iOS）の告知、開発状況、サーバー状況、開発に伴う技術説明を掲載するサイトです（[#131](https://github.com/m0o9l0v3/NexusMobile/issues/131)）。参加者向けアプリ機能は iOS アプリだけが持ち、このサイトは代替機能を持ちません。

現在は準備中の1ページだけです。ページ構成と各項目のデータ源は #131 の「未決」を決めてから実装します。方針転換前の参加者向け PWA は 2026-10-25 に削除しました（必要なら git 履歴から参照できます）。

## 開発

```bash
npm install
npm run dev        # http://localhost:5176
npm run typecheck
npm run build      # dist/ に出力（git では追跡しない）
```
