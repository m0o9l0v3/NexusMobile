# バックアップ → 復元のリハーサル記録（2026-11-14、#71）

手順は [docs/backup-restore.md](../../backup-restore.md)。**使い捨て環境だけで行い、本番には接続していない。**

| 項目 | 値 |
|---|---|
| 実行 | `tools/database/rehearse-pg17-restore.sh`（2026-11-14 14:51〜14:53 UTC） |
| 環境 | Mac、colima プロファイル `nexus-db-verify`（aarch64）、Docker Compose 5.5.1 |
| NexusMobile | `bf097dd`（`develop`）＋本 PR の `deploy/database/restore-fingerprint.sql` |
| NexusInfra | `main` `228176e`（`compose.pg17-restore.yml`、`preflight-rehearsal.py`、`01-roles.sql`） |
| PostgreSQL | `postgres@sha256:b0f9560a2de083e2cc7382e75f808c7381a32852a7ec49117deedb300e552b24`（17.11） |
| public-api | `bf097dd` からローカルでビルド（`sha256:ce8c7b8d…`、linux/arm64）。本番の採用 digest ではない |
| 移行 SQL | SHA-256 `7cf58c307611ebec07e617add3f18d7fa65eee30c6de16dc2d989d5e4a9da763`（.NET 8 SDK のコンテナで生成。NexusInfra issue-8 資料の固定値と同じ） |

## 結果

| # | 確認 | 結果 |
|---|---|---|
| 1 | 元の DB に baseline（01-roles → 移行 SQL → grant-runtime）を適用 | 合格（2秒） |
| 2 | 合成データと、public-api 経由のログ50件 | 合格。公開スポットは API で30件（40件中、非公開10件） |
| 3 | `backup-pg17-source.sh` と同じ3つの dump、`pg_restore -l`、`SHA256SUMS`、照合値 | 合格（`nexus.dump` 31,349 bytes） |
| 4 | 別ディレクトリへのコピーと `shasum -c` | 合格（3ファイル OK）。以降は元を止め、コピーだけを使った |
| 5 | NexusInfra の preflight と、新しい空 volume への PG17 の起動 | 合格（17.11） |
| 6 | ロールを先に作らない復元（NexusInfra Phase 1 の例のまま） | **予想どおり失敗**：`role "nexus_admin_app" does not exist`（`CREATE POLICY nexus_admin_all ON public.events`） |
| 7 | 手順の3節の順序での復元 | 合格（7秒） |
| 8 | 照合値の比較（59行） | 一致（[元](fingerprint-source.txt) と [復元先](fingerprint-restored.txt) が同一） |
| 9 | `audit-verify`（保管した鍵） | 元と同じ結果：`FAILED: audit chain broken at visit_logs.id 26344498-…`（手順の6節の既知の不具合。復元による変化ではない） |
| 10 | `audit-verify`（別の鍵） | FAILED |
| 11 | 復元先で public-api を起動 | 合格（起動時の検査に合格し healthy、公開スポット30件、新しいログ5件が既存のチェーンの hash につながった） |
| 12 | 元の volume | 止めた元のコンテナだけにつながったまま |

全体の出力は [rehearsal.log](rehearsal.log)、入力のハッシュは [inputs.txt](inputs.txt)。実行で作ったコンテナ・volume・network はスクリプトが削除した。秘密（パスワード、`audit_key`）は実行ごとの乱数で、記録のファイルに含まれないことを照合した。

## この記録が示さないこと

- 本番のデータ量・`linux/amd64`・VPS からの転送での所要時間
- Studio の `studio`・`delivery` スキーマを含む復元
- 第2段階（pgBackRest）。こちらは `tools/database/verify.py` の記録（[2026-11-02](../local-backup-2026-11-02.json)）を参照
