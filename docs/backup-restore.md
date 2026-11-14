# バックアップと復元の手順（E8-5）

- Issue: [#71](https://github.com/m0o9l0v3/NexusMobile/issues/71)
- 状態: **手順と使い捨て環境でのリハーサルまで。本番未適用。** 本番の VPS・DB には接続していない。本番で行う手順は、9節の承認を受けてから運用者が実行する
- 作成日: 2026-11-14

## 0. この文書が扱う範囲

本番 DB は2段階で導入する（[本番DBの採用・運用方針](decisions/production-database.md) §0）。手順の正本は段階ごとに分かれている。本書はそれを置き換えない。**NexusMobile のデータ（`public` スキーマ）が正しく戻ったと言える条件**と、そのための復元の順序・確認方法を定める。

| 段階 | バックアップ・復元のコマンドの正本 | 本書で足すもの |
|---|---|---|
| 第1段階（v1.0。既存の PostgreSQL 17、DB `nexus`） | NexusInfra [`transition-postgres-17-to-18.md`](https://github.com/m0o9l0v3/NexusInfra/blob/main/docs/transition-postgres-17-to-18.md) Phase 1（`scripts/backup-pg17-source.sh`、`compose.pg17-restore.yml`）、[`pg17-issue-8-production-apply.md`](https://github.com/m0o9l0v3/NexusInfra/blob/main/docs/pg17-issue-8-production-apply.md) の承認A | 3節の復元順序（**ロールを先に作る**）、4節の照合、5節の合否基準 |
| 第2段階（PostgreSQL 18 ＋ pgBackRest） | [Macへのバックアップ保存と復元](database-backup-to-mac.md)、[本番DBの構築・検証手順](production-database-runbook.md) | 4節の照合を月次の復元確認に加える（6節） |

## 1. バックアップに含めるもの

DB のダンプだけでは戻らない。次をそろえて VPS の外（Mac）に保管する。

| 対象 | 置き場所 | 無いと何が起きるか |
|---|---|---|
| DB のダンプ（第1段階は `nexus.dump`・`globals.sql`・`cluster.sql` と `SHA256SUMS`） | Mac。暗号化して保管（NexusInfra Phase 1） | 復元できない |
| 取得時の照合値（`restore-fingerprint.sql` の出力。2節） | ダンプと同じ保存先 | 戻ったかどうかを比べる基準が無い |
| `audit_key`（監査ログの HMAC 鍵） | ダンプとは**別**の保護された場所（`backup_cipher` と同じ扱い） | 監査チェーンを検証できない。鍵を作り直すと過去のログはすべて不合格になる |
| イメージの digest（PG17、public-api）と、移行 SQL の SHA-256 | 運用記録（秘密ではない） | 同じ版で戻せない |
| 秘密情報の作り直し方（`nexus_public` のパスワードなど） | 運用記録 | `pg_dumpall --no-role-passwords` なのでパスワードは戻らない。復元先では作り直す（3節） |

## 2. バックアップの取得（第1段階・本番・要承認）

1. NexusInfra Phase 1 の手順で `backup-pg17-source.sh` を実行する（承認A）
2. **同じ作業時間のうちに**、元の DB で照合値を取る。読み取り専用のトランザクションで、件数・移行履歴・`map_datasets` の checksum と payload の SHA-256・チェーンごとの件数と末尾の hash・ロールと権限の状態だけを出す。行の中身と秘密は出さない

   ```sh
   docker exec -i --user postgres <PG17_CONTAINER> psql -X -At -v ON_ERROR_STOP=1 -U nexus -d nexus \
     < deploy/database/restore-fingerprint.sql > <バックアップの保存先>/fingerprint-source.txt
   ```

3. public-api が動いている間は `visit_logs` が増えるので、照合値の `visit_logs` はダンプより多いことがある（5節で扱う）。移行前のバックアップは public-api を止めてから取るので、完全に一致するはず

## 3. 復元の順序（第1段階・隔離環境）

Mac の隔離 PG17（`compose.pg17-restore.yml`、新しい空 volume）へ戻す。NexusInfra Phase 1 の準備（`preflight-rehearsal.py pg17`、`config --quiet`、`up -d --wait`、`postgres --version` が17系、`SHA256SUMS` の照合）はそのまま行う。そのあとの `pg_restore` を次の順に置き換える。

**理由**: baseline（NexusInfra の B1〜B3）を本番に当てた後のダンプには、`spots`・`events` の RLS ポリシーが入っている。ポリシーは `TO nexus_public`・`TO nexus_admin_app` とロールを名指しするので、ロールの無い復元先では `pg_restore --exit-on-error` が `role "nexus_admin_app" does not exist` で止まる（2026-11-14 のリハーサルで確認。8節）。現在の Phase 1 の例は baseline の前の空の DB を想定したもので、そのままでは使えない。また `--no-owner` だけでは表の所有者が `postgres` になり、後の移行（`SET ROLE nexus_owner`）が表を変えられない。

```sh
# 復元先は隔離環境だけ。RC は「docker compose -p "$PG17_RESTORE_PROJECT" -f compose.pg17-restore.yml」
# (1) ロールを先に作る。パスワードは復元先用に新しく作り、ファイルから環境変数へ読む（値を表示しない）
export NEXUS_PUBLIC_PASSWORD="$(cat <復元用の私有ディレクトリ>/nexus_public_password)"
docker exec -i -e NEXUS_PUBLIC_PASSWORD "$(RC ps -q postgres)" psql -X -q -v ON_ERROR_STOP=1 -U postgres -d "$PG17_DB_NAME" \
  < <NexusInfra>/sql/pg17-baseline/01-roles.sql
unset NEXUS_PUBLIC_PASSWORD
# (2) 所有者を nexus_owner にして戻す
RC exec -T postgres pg_restore -U postgres -d "$PG17_DB_NAME" --no-owner --no-acl --role=nexus_owner --exit-on-error \
  < "$PG17_BACKUP_COPY_DIR/nexus.dump"
# (3) 権限を戻す（--no-acl で GRANT は入らない）
{ printf 'SET ROLE nexus_owner;\n'; cat deploy/database/grant-runtime.sql; } | \
  RC exec -T postgres psql -X -q -v ON_ERROR_STOP=1 -U postgres -d "$PG17_DB_NAME"
# (4) 照合値を取って比べる
RC exec -T postgres psql -X -At -v ON_ERROR_STOP=1 -U postgres -d "$PG17_DB_NAME" \
  < deploy/database/restore-fingerprint.sql > fingerprint-restored.txt
diff -u "$PG17_BACKUP_COPY_DIR/fingerprint-source.txt" fingerprint-restored.txt
```

- Studio の `studio`・`delivery` スキーマがある場合（NexusInfra の承認C の後）は、(1) の後に Studio のロールも先に作る必要がある（NexusStudio `deploy/database/pg17/setup-studio-roles.sql`）。**この組み合わせはまだリハーサルしていない**（10節）
- `NEXUS_PUBLIC_PASSWORD` が空だと `01-roles.sql` は何もせずに終了コード0で終わる（NexusInfra issue-8 資料 3.2節）。(4) の照合値に `role|nexus_public|login=true` があることで確かめる
- `globals.sql` を盲目的に流さない（NexusInfra Phase 1 と同じ）。ロールは (1) で作る

## 4. 復元後の照合

| # | 確認 | 方法 |
|---|---|---|
| R1 | PG のメジャー版が元と同じ | `restore-fingerprint.sql` の `server_major` |
| R2 | 移行履歴が元と同じ（第1段階は2行：`20260905120000_AddMapDatasets`、`20260919120000_AddInitialPostgreSqlSchema`） | `migration|` の行 |
| R3 | 全表の件数が元と同じ | `rows|` の行 |
| R4 | 公開した地図データのバイト列が同じ | `map_dataset|`（checksum と payload の SHA-256） |
| R5 | ロール・所有者・RLS・ポリシー・`nexus_public` の権限が契約B のとおり | `role|`・`owner|`・`rls|`・`policy|`・`grant|` の行 |
| R6 | 監査チェーンの件数と末尾の hash が元と同じ | `audit_chain|` の行 |
| R6a | 監査ログの全行・全列が元と同じ（チェーンごとの件数と、行ごとの SHA-256 を `created_at, id` の順につないだ SHA-256） | `audit_rows|` の行 |
| R7 | 監査チェーンの全件検証が元と同じ結果 | 復元先で `audit-verify`（下） |
| R8 | public-api が復元先で起動し（起動時の検査に合格）、公開スポットの件数が元と同じ。ログを書くと既存のチェーンにつながる | 復元先に public-api をつなぐ（リハーサルでは `GET /api/spots/public`、`POST /api/logs/batch`） |
| R9 | 元の volume が変わっていない | NexusInfra Phase 1 の記録（container ID・mount・volume） |

`audit-verify` は最初に壊れた行で止まるので、それより後の行が復元で変わっても R7 だけでは分からない。R6a はそれを補い、すべての行（`payload_json`・位置・`session_id` を含む）を元と比べる。出力はダイジェストだけで、行の中身は出さない。時刻は UTC のマイクロ秒で文字にするので、接続の TimeZone の違いでは変わらない。

`audit-verify` は**復元した隔離 DB に対して**、その中の superuser で実行する。本番の DB でどの role を使うかはまだ決まっていない（[E8-7 r1](decisions/E8-7-r1-admin-api-removal.md) の残課題）。復元先で行えば、本番に新しい role を作らずに全件を検証できる。

```sh
# 復元先の network に入れたコンテナから。接続文字列と鍵はファイルで渡す
NEXUS_AUDIT_CONNECTION_FILE=<復元先 superuser の接続文字列のファイル> \
NEXUS_AUDIT_HASH_KEY_FILE=<別保管の audit_key> \
  dotnet run --project tools/database/Nexus.Database.csproj -- audit-verify
```

## 5. 合否基準

**合格**は次のすべてを満たすとき。1つでも外れたら不合格で、その写しを使った切り替えや、移行・本番作業へ進まない。

| 基準 | 合格 | 不合格の例 |
|---|---|---|
| 整合 | `SHA256SUMS` がすべて OK、`pg_restore --exit-on-error` が 0 で終わる | ハッシュ不一致、途中で止まる |
| 照合値 | `diff` が空。ただし public-api を止めずに取ったバックアップでは、`visit_logs` の件数と `audit_chain` の行だけ「復元先 ≦ 元」を許す。`audit_rows` は1行増えても値が変わるのでこの場合は比べられない。R6a を確かめるには public-api を止めて（ログの書き込みが無い状態で）取ったバックアップを使う | 移行履歴・`map_dataset`・権限・`audit_rows` の行が1つでも違う |
| 監査チェーン | `audit-verify` が PASS。**6節の不具合が直るまでは「元の DB と同じ結果」かつ `audit_rows` が一致**を合格とする。FAILED の文言が同じだけでは、止まった行より後を見ていないので合格にしない | 元より手前の行で FAILED になる、別の鍵で PASS になる、`audit_rows` が違う |
| API | public-api が起動し、R8 が成り立つ | 起動時の検査（移行履歴・role）で止まる |
| 記録 | 所要時間、各段の結果、使った digest と入力の SHA-256 を運用記録に残した | 記録が無い |

## 6. 監査チェーンの既知の不具合（2026-11-14 に判明）

リハーサルで、public-api が書いたばかりの `visit_logs` が**元の DB でも** `audit-verify` に不合格になった。50件中49件の hash が、保存された値から計算し直した値と合わない。

- 原因: `LogPersistenceService` は `DateTimeOffset.UtcNow`（100ナノ秒単位）のまま `occurred_at`・`created_at` を HMAC の入力にする（`AuditLogHasher.BuildCanonicalString` の `"O"` 形式は小数7桁）。PostgreSQL の `timestamptz` はマイクロ秒（6桁）までしか持たないので、保存した値で計算し直すと7桁目が 0 になり一致しない。不一致だった行の1件で、7桁目（0〜9）を補うと保存された hash に一致する値があることを確かめた
- 影響: 本番で `audit-verify` を使っても改ざんの有無を判定できない。バックアップ・復元の問題ではない（復元先でも元と同じ行で止まる）
- 直し方の案: hash を計算する前に時刻をマイクロ秒へ切り捨てる。本番の `visit_logs` はまだ無いので、既存データの移行は要らない。修正は別の PR で行う（10節）
- 修正までは5節の「元の DB と同じ結果」を基準にし、修正後は `STRICT_AUDIT=1` でリハーサルし PASS を基準にする

## 7. 頻度と記録

- 復元確認は、公開前、移行（スキーマ変更）の前、月1回に行う（[採用方針](decisions/production-database.md) §3 と同じ）
- 記録するもの: 日時、使ったバックアップ（保存先・SHA-256）、digest、所要時間（取得・転送・復元）、R1〜R9 の結果、不合格なら原因と対処
- RPO は「最後に VPS の外へ正常にコピーした時点」、RTO は実データ量で測るまで約束しない（NexusInfra [`disaster-recovery.md`](https://github.com/m0o9l0v3/NexusInfra/blob/main/docs/disaster-recovery.md)）。リハーサルの所要時間（下）は合成データ数十行のもので、本番の見積もりには使わない

## 8. リハーサル（2026-11-14、使い捨て環境）

[`tools/database/rehearse-pg17-restore.sh`](../tools/database/rehearse-pg17-restore.sh) で、元の DB の構築からバックアップ・別 volume への復元・照合までを1回通した。記録は [`docs/verification/backup-restore-2026-11-14/`](verification/backup-restore-2026-11-14/README.md)。

```sh
DOCKER_CONTEXT=colima-nexus-db-verify NEXUS_INFRA_DIR=../nexus-infra \
PUBLIC_API_IMAGE=<public-api のイメージ> bash tools/database/rehearse-pg17-restore.sh
```

- 環境: Mac の colima（aarch64）、PG17.11（隔離検証の採用 digest `b0f9560a…`）、public-api は `develop` `bf097dd` からローカルでビルドしたもの（本番の採用 digest `847b6d0f…` は `linux/amd64` のため使わない）
- 元: NexusInfra `01-roles.sql` → 移行 SQL（SHA-256 `7cf58c30…`、NexusInfra の固定値と同じ）→ `grant-runtime.sql` → 合成データ（spots 40、events 12、map_datasets 3）→ public-api 経由でログ50件
- バックアップ: `backup-pg17-source.sh` と同じ3つの dump と `SHA256SUMS`、照合値。別ディレクトリへコピーしてハッシュ照合し、元を止めた
- 復元: NexusInfra `compose.pg17-restore.yml`（`main` `228176e`）と新しい空 volume
- 結果: すべて合格。ロールを先に作らない復元は予想どおり失敗した。照合値60行が一致（監査ログ全行のダイジェスト `audit_rows` を含む。最新の1行の `session_id` だけを変えた写しでは `audit_rows` が変わることも確かめた）、`audit-verify` は元と同じ行で FAILED（6節）、別の鍵でも FAILED、public-api が復元先で起動し公開スポット30件、新しいログ5件が既存のチェーンにつながった。復元（ロール作成から権限まで）は6秒
- 片付け: この実行で作ったコンテナ・volume・network はスクリプトが削除した。秘密はすべて使い捨ての乱数で、記録に含まれないことを確かめた

## 9. 本番で承認が必要な手順

| # | 手順 | 承認 |
|---|---|---|
| P-1 | NexusInfra Phase 1 のバックアップ取得と VPS 外へのコピー（2節1） | NexusInfra 承認A |
| P-2 | 元の DB で `restore-fingerprint.sql` を実行する（2節2、読み取りのみ） | 承認A に含める |
| P-3 | `audit_key` を VPS の外の別の場所に保管する（1節） | 要承認（秘密の扱い） |
| P-4 | 隔離環境（Mac）での復元と照合（3〜5節） | 本番には触れないが、本番のデータを扱うので承認A の一部として行う |
| P-5 | 月1回の復元確認を運用に組み込む（7節） | 運用の決定 |

## 10. 残っていること

- 6節の監査チェーンの不具合の修正（別 PR）
- NexusInfra の Phase 1 の復元例を3節の順序（ロールを先に、`--role=nexus_owner`、権限を後から）に合わせる。NexusInfra 側の変更なので本 PR には含めない
- Studio のスキーマ（`studio`・`delivery`）を含む復元のリハーサル（NexusInfra 承認C の後）
- 本番のデータ量・CPU アーキテクチャ（`linux/amd64`）での所要時間の測定
- `tools/database/rehearse-pg17-restore.sh` の構文検査を CI に加えるかどうか（CI の変更は別の作業と重なるため本 PR では行わない）
