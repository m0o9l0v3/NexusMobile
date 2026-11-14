# デプロイ・ロールバックのリハーサル記録（2026-11-15 JST、#73）

手順は [docs/deploy-rollback.md](../../deploy-rollback.md)。**使い捨て環境だけで行い、本番には接続していない。**

| 項目 | 値 |
|---|---|
| 実行 | `tools/database/rehearse-deploy.sh`（2026-11-14 14:59〜15:02 UTC） |
| 環境 | Mac、colima プロファイル `nexus-db-verify`（aarch64） |
| NexusMobile | `e81a82a`（`develop`）。移行 SQL は .NET 8 SDK のコンテナで生成し、SHA-256 `7cf58c30…`（NexusInfra issue-8 資料の固定値と同じ） |
| NexusInfra | `main` `228176e`（`sql/pg17-baseline/01-roles.sql`） |
| PostgreSQL | `postgres@sha256:b0f9560a…`（17.11） |
| 今回のイメージ（NEW） | `bf097dd` からローカルでビルドした public-api（`sha256:ce8c7b8d…`）。`bf097dd..e81a82a` の間に `apps/public-api`・`apps/nexus-data`・`deploy`・`tools/database` の変更は無い |
| 前回のイメージ（PREV） | `31c2fb0`（admin-api の削除の前、CORS 修正の後）からローカルでビルドした public-api（`sha256:a0cf49a4…`）。移行は今回と同じ2本（`apps/admin-api/Migrations` から `apps/nexus-data/Migrations` へは名前の変更だけ） |

どちらのイメージも本番の採用 digest ではない（本番は `linux/amd64`、GHCR から取得）。

## 結果

| # | 確認 | 結果 |
|---|---|---|
| D1 | 移行の前に新しいイメージを起動 | 起動しない：`Database migration history differs from this application. Apply the reviewed deployment SQL first.` |
| D2 | 移行 SQL → `grant-runtime.sql` → 新しいイメージ | healthy、`/health` 200、`/api/spots/public` 200、ログを受け付けた。履歴は2本 |
| D3 | 同じ移行 SQL をもう一度 | 何も変わらない（履歴が同じ） |
| D4 | 前のイメージへ戻し、また新しいイメージへ | どちらも healthy、どちらでもログを書けた |
| D5 | 新しい移行が当たった状態（履歴に1行足して模した） | 動いているプロセスは応答を続けた。再起動すると止まり、前のイメージも起動しない（D1 と同じ例外） |
| D6 | 今の移行 SQL を、新しい移行のある DB へ | 拒否：`Unknown migration history detected. Stop and review.` |
| D7 | API が動いている間に DB を止める | `/health` は 200 のまま、`/api/spots/public` は 500。DB を戻すと同じプロセスが 200 に戻った |

全体の出力は [rehearsal.log](rehearsal.log)、入力のハッシュは [inputs.txt](inputs.txt)。D5 で足した行は、使い捨ての DB の上で D6 の後に削除した（本番で履歴を手で書き換えることはしない）。実行で作ったコンテナ・volume・network はスクリプトが削除した。秘密は実行ごとの乱数で、記録のファイルに含まれないことを照合した。

## この記録が示さないこと

- GHCR からの取得、`linux/amd64`、Caddy 経由の確認（NexusInfra#7・#17 の範囲）
- `/api/v2/bundle`（`delivery` は Studio の移行で作るため、この環境には無い）
- 実データ量での移行のロック時間と停止時間
