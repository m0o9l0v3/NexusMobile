# セキュリティメモ

> 2026-11-14：本書の前半は文字化け（UTF-8 の二重変換）していたため、内容を読み戻して書き直した。

## 削除した機能（QR ワンタイムログイン・JWT 失効）

管理 API（admin-api）と hidden beta（QR 発行・ワンタイムコード・`/q/{token}`・JWT の発行と失効）は、v1.0 の本番に置かないため 2026-11-14 に削除した（[E8-7 r1](decisions/E8-7-r1-admin-api-removal.md) D-1・D-4）。コードと、ここに書いていた脅威と対策（ワンタイムコードの HMAC 保存・即時失効・当日 23:59:59 JST の期限、`jti` の記録と `revoked_jti` による失効）は、コミット `fb539f7` の `apps/admin-api` と本書に残っている。

- `qr_issues`・`one_time_login_codes`・`issued_tokens`・`revoked_jti` などの表は、移行履歴を変えないため残している（D-11）。書く API は無く、`nexus_public` からは読めない。
- 復元する場合は、上の設計（平文で保存しない、引換後すぐ失効、全リクエストで失効を確かめる）を守る。共有の型は `apps/nexus-data`（`Nexus.Data`）にあるので、そこを参照する形に付け替える。

## 監査ログ（visit_logs）の改ざん検知

- 目的：監査ログの改ざんを「完全に防ぐ」のではなく「検知できる」ようにする。本番で運用する（E8-7 r1 D-5）。
- 方式：
  - 各ログに `prev_hash`（直前のログのハッシュ）と `hash`（自身の HMAC）を保存し、チェーンにする。書くのは public-api の `LogPersistenceService` だけで、ハッシュは `AuditLogHasher`（`apps/nexus-data`）が計算する。
  - 連結の対象は `occurredAtUtc`・`createdAtUtc`・`sessionId`・`eventType`・`spotCode`・`chainId`・`prevHash` を正規化した文字列。
  - 時刻（`occurredAtUtc`・`createdAtUtc`）は**マイクロ秒に切り捨ててから**使う。PostgreSQL の `timestamptz` はマイクロ秒までしか持たないので、100 ナノ秒単位の値のまま計算すると、保存した値から計算し直したハッシュと一致しない（[`backup-restore.md`](backup-restore.md) §6）。保存する値そのもの（`LogPersistenceService`・`AdminDbContext`。端末から届いた `OccurredAt` も含む）と、`AuditLogHasher` の入力の両方を `AuditTimestamp.TruncateToMicroseconds` で切り捨てる。文字列は UTC の `"O"` 形式で、小数7桁目は常に 0 になる。
  - ハッシュ方式は `HMAC-SHA256`。鍵（`AuditLog:HashKey`）は秘密ファイルで注入する。
  - `chain_id` は日（UTC）ごとに分かれる。
- 検証：`tools/database` の `audit-verify` で行う（`AuditLogVerificationService`）。セッションを `default_transaction_read_only=on` にして読むだけで、書き込みは DB 側で拒否される。接続文字列と鍵はファイルから読み、値を出力しない。チェーンが壊れていれば最初の不整合の `visit_logs.id` を出して終了コード 1 で終わる。

  ```bash
  NEXUS_AUDIT_CONNECTION_FILE=/path/to/connection NEXUS_AUDIT_HASH_KEY_FILE=/path/to/audit_key \
    dotnet run --project tools/database/Nexus.Database.csproj -- audit-verify [--chain visitlog-20261114] [--from 2026-11-14T00:00:00Z] [--to ...]
  ```

  - 接続には `visit_logs` の全列を読めるロールが要る。`nexus_public` は3列しか読めず、`nexus_admin_app` は NOLOGIN（D-7）なので、本番でどのロールで実行するかは NexusInfra の手順で決める（未決）。
  - 使い捨て DB の検証（`tools/database/verify.py`）で、正しいチェーンを通し、1行を書き換えると検知することを確かめている。
- 限界：
  - 鍵が漏れると、ハッシュを偽造できるため検知できなくなる。
  - DB の権限を持つ攻撃者がログを削除・並べ替えた場合、チェーンの不整合として検知できるが、元には戻せない。
  - 導入前のログはハッシュを持たないため、検証の対象外。
- TODO：鍵のローテーションと、過去のチェーンの検証の運用を決める。


## Rate limiting

レート制限の対象・既定値・設定は [rate-limiting.md](rate-limiting.md) を参照。


## Secret 管理

- リポジトリに Secret の実値を置かない。`docker-compose.yml` には `CHANGE_ME_*` や平文パスワードを書かない。
- ローカル: `tools/dev-secrets.sh` が `.env`（git 管理外・権限 600）へ `NEXUS_DEV_DB_PASSWORD` / `NEXUS_DEV_AUDIT_HASH_KEY` を生成する。未生成なら Compose は起動しない。既存値は上書きしない。
- 本番: サーバー上の秘密ファイルを Compose secrets としてマウントし、`*File` 設定（`DatabaseRuntimeConfiguration.LoadSecretFiles`）で読み込む。非 Development では `RequireSecret` が `CHANGE_ME` 等の既定値を拒否する。詳細は [decisions/production-database.md](decisions/production-database.md)。
- 漏えい時は該当 Secret を再生成して再起動する。監査ログ HMAC 鍵の変更は既存チェーンの検証に影響するため、ローテーション戦略（上記 TODO）と合わせて扱う。
