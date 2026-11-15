# 監査チェーンの修正後のリハーサル記録（2026-11-15、`STRICT_AUDIT=1`）

[2026-11-14 の記録](../backup-restore-2026-11-14/README.md)と同じ手順を、監査チェーンの不具合（[docs/backup-restore.md](../../backup-restore.md) §6）を直したコードでもう一度行った。今回は `STRICT_AUDIT=1` を付け、元の DB の `audit-verify` が PASS でなければ止まるようにした。**使い捨て環境だけで行い、本番には接続していない。**

| 項目 | 値 |
|---|---|
| 実行 | `STRICT_AUDIT=1 tools/database/rehearse-pg17-restore.sh`（2026-11-15 00:16〜00:17 UTC） |
| 環境 | Mac、colima プロファイル `nexus-db-verify`（aarch64） |
| NexusMobile | `fcd7dc2`（`fix/audit-chain-microsecond`） |
| NexusInfra | `main` `228176e` |
| PostgreSQL | `postgres@sha256:b0f9560a…`（17.11、前回と同じ） |
| public-api | `fcd7dc2` からローカルでビルド（`sha256:2d9a6186…`、linux/arm64）。本番の採用 digest ではない |
| 移行 SQL | SHA-256 `7cf58c30…`（前回と同じ。この修正はスキーマを変えない） |

## 結果

| # | 確認 | 結果 |
|---|---|---|
| 1 | 元の DB に baseline を適用 | 合格（3秒） |
| 2 | public-api 経由のログ50件と、元の DB での `audit-verify` | **PASS**（前回は 50件中49件が不一致で FAILED） |
| 3 | バックアップ、`SHA256SUMS`、照合値 | 合格（`nexus.dump` 31,316 bytes） |
| 4 | ロールを先に作らない復元 | 予想どおり失敗 |
| 5 | 3節の順序での復元と照合値の比較（59行） | 一致（復元は7秒） |
| 6 | 復元先での `audit-verify`（保管した鍵） | **PASS**（元と同じ） |
| 7 | 復元先での `audit-verify`（別の鍵） | FAILED |
| 8 | 復元先で public-api を起動 | 合格（公開スポット30件、新しいログ5件が復元したチェーンにつながった） |
| 9 | 元の volume | 止めた元のコンテナだけにつながったまま |

全体の出力は [rehearsal.log](rehearsal.log)、入力のハッシュは [inputs.txt](inputs.txt)、照合値は [元](fingerprint-source.txt) と [復元先](fingerprint-restored.txt)。作ったコンテナ・volume・network はスクリプトが削除した。秘密は実行ごとの乱数で、記録のファイルに含まれないことを照合した。

## 途中で見つかったこと

最初の実行では public-api がログを1件も保存できなかった（`permission denied for table visit_logs`）。前の行の hash を探すときに `id` で並べ替える変更を入れていたが、`nexus_public` は `visit_logs` の `chain_id`・`created_at`・`hash` しか読めない（`deploy/database/grant-runtime.sql`）。その並べ替えはやめ、同じバッチの `created_at` を 1 マイクロ秒ずつずらして重ならないようにした。InMemory のテストでは列の権限が無いので見つからない。
