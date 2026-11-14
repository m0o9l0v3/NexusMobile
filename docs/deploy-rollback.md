# デプロイとロールバックの手順（E8-6）

- Issue: [#73](https://github.com/m0o9l0v3/NexusMobile/issues/73)（依存: E8-1 [#67](https://github.com/m0o9l0v3/NexusMobile/issues/67)・E8-2 [#70](https://github.com/m0o9l0v3/NexusMobile/issues/70)、どちらも Close 済み）
- 状態: **手順と使い捨て環境でのリハーサルまで。本番未適用。** 本番の VPS・DB・Caddy・DNS には接続していない。本番で行う手順は、9節の承認を受けてから運用者が実行する
- 作成日: 2026-11-15

## 0. この文書が扱う範囲

本番の構成と最初の導入は NexusInfra が持つ。本書はそれを繰り返さず、**NexusMobile の成果物（public-api のイメージ、`apps/nexus-data` の移行、配信）をどの順で出し、どう戻すか**を定める。

| 対象 | 正本 | 本書で足すもの |
|---|---|---|
| edge（Caddy ＋ public-api）の導入・停止・前の digest への戻し | NexusInfra [`pg17-public-edge.md`](https://github.com/m0o9l0v3/NexusInfra/blob/main/docs/pg17-public-edge.md) §10・§11（[NexusInfra#6](https://github.com/m0o9l0v3/NexusInfra/issues/6)） | どの変更なら「前の digest へ戻す」が使えるか（2節・5節） |
| 最初の DB 準備（バックアップA → public-api の baseline B → Studio の DB C） | NexusInfra [`pg17-issue-8-production-apply.md`](https://github.com/m0o9l0v3/NexusInfra/blob/main/docs/pg17-issue-8-production-apply.md)（[NexusInfra#8](https://github.com/m0o9l0v3/NexusInfra/issues/8)） | v1.0 公開後の**次の移行**の手順（4.2節） |
| Studio の公開ルート | [NexusInfra#9](https://github.com/m0o9l0v3/NexusInfra/issues/9) | — |
| 配信表 `delivery` の権限、Caddy 経由の ETag/304 | [NexusInfra#17](https://github.com/m0o9l0v3/NexusInfra/issues/17) | 配信の「戻し」は Studio の新しい Release（5節） |
| バックアップと復元 | [バックアップと復元の手順](backup-restore.md)（E8-5、#71） | 移行の前に必ず通す（4.2節） |
| TLS・秘密情報 | [E8-1](decisions/E8-1-https-tls-termination.md)、E8-2（#70） | — |

## 1. 出すもの

| 成果物 | 作り方 | 本番での識別 |
|---|---|---|
| public-api のイメージ | `.github/workflows/public-api-image.yml`（手動実行。レビュー済みの commit SHA と VPS の platform を入力。環境 `public-api-image` の承認を通る）→ `ghcr.io/m0o9l0v3/nexus-public-api-pg17-private`（Private） | `@sha256:` の digest。発行ジョブの URL と commit を一緒に記録する |
| 移行 SQL | `dotnet run --project tools/database/Nexus.Database.csproj -- script <file>`（DB に接続しない） | SHA-256。適用日に生成し直して一致を確かめる |
| 権限 SQL | `deploy/database/grant-runtime.sql` | SHA-256 |
| 配信（参加者向け bundle） | NexusStudio の公開（Release）。NexusMobile からは出さない | `bundle_version`（単調に増える） |

参加者の iOS アプリが使う API は `GET /api/v2/bundle` だけ。公開サイト（`web/`）はサーバー状況のページで `GET /health` だけを呼ぶ。

## 2. 守るべき規則（コードとリハーサルで確かめたこと）

| # | 規則 | 根拠 | リハーサル |
|---|---|---|---|
| G-1 | public-api は**起動時に**、DB の移行履歴が自分の持つ移行の一覧と**完全に一致**するかを確かめ、違えば起動しない | `apps/nexus-data/Data/DatabaseReadiness.cs` | D1・D5 |
| G-2 | この確認は起動時だけ。動いているプロセスは、後から移行が当たっても動き続ける。再起動した時点で止まる（`restart: unless-stopped` なら再起動を繰り返す） | 同上 | D5 |
| G-3 | 移行 SQL は同じものを何度流しても変わらない。知らない移行（新しい移行）がある DB には何もせず拒否する | `tools/database/Program.cs` の preflight | D3・D6 |
| G-4 | 移行の Down は無い（`AddInitialPostgreSqlSchema.Down` は `NotSupportedException`）。自動の逆移行もしない | [本番DBの採用・運用方針](decisions/production-database.md) §4 | — |
| G-5 | `/health` は DB を見ない。DB が止まっていても 200 を返す。成功の判定には DB を読む要求を使う | `apps/public-api/Program.cs` | D7 |
| G-6 | `grant-runtime.sql` は `spots`・`events` に AccessExclusive のロックを取る。public-api が動いている間に流すと、その間の読み取りが止まる | NexusInfra issue-8 資料 3.1節 | — |
| G-7 | 移行の一覧が同じイメージ同士なら、どちらにも入れ替えられる | G-1 から | D4 |

G-1〜G-3 から、**移行を含む変更では「前のイメージに戻す」が使えない**（D5）。移行の後に戻せるのは、移行の前のバックアップから DB を戻す場合だけで、それ以外は前へ直す（forward-fix）。

## 3. 変更の種類の見分け方

前回デプロイした commit を `<deployed>`、今回の commit を `<new>` とする（どちらも運用記録にある）。

```sh
git diff --stat <deployed> <new> -- apps/nexus-data/Migrations deploy/database/grant-runtime.sql tools/database/Program.cs
```

- 出力が空 → **イメージだけの変更**（4.1節）。移行の一覧が同じなので、前の digest へいつでも戻せる
- 出力がある → **移行を含む変更**（4.2節）
- `apps/admin-api/Migrations` から `apps/nexus-data/Migrations` への移動（#181）は名前の変更だけで、移行 SQL の SHA-256（`7cf58c30…`）は変わっていない。`git diff --stat -M` で 0 行の変更として出る

## 4. デプロイの手順（本番・要承認）

### 4.0 最初の導入（v1.0）

NexusInfra の順序のとおりに行う。本書の手順はこの後に使う。

1. `pg17-issue-8-production-apply.md` の承認A（バックアップと隔離環境での復元。復元は [backup-restore.md](backup-restore.md) 3節の順序で行う）
2. 同じ資料の承認B（public-api の baseline：`01-roles.sql` → 移行 SQL → `grant-runtime.sql` → 確認）
3. 同じ資料の承認C（Studio の DB。`/api/v2/bundle` が読む `delivery` を作る）
4. `pg17-public-edge.md` §10（edge の起動）。成功の判定は本書6節

### 4.1 イメージだけの変更

1. `<new>` で CI がすべて通っていることを確かめる
2. `public-api-image.yml` で発行し、digest・ジョブの URL・commit・platform を記録する（承認 P-2）
3. NexusInfra §10 の手順で、私有 env の `PG17_EDGE_PUBLIC_API_IMAGE` を新しい digest にし、検査（`validate-pg17-edge.py --env`、`config`）の後に `up -d --wait`（承認 P-3）
4. 6節で判定する。失敗なら 5節の L-1 で前の digest に戻す

### 4.2 移行を含む変更

API を止める時間を取る。参加者の iOS アプリは保存済みの bundle を使い続ける（7節）ので、オープンキャンパスの当日と前日は避ける。

| # | 手順 | 止める条件 |
|---|---|---|
| M-1 | `<new>` で CI がすべて通っている。新しい移行の ID が `tools/database/Program.cs` の preflight の既知の一覧にも入っている（入っていないと移行 SQL が自分の移行を「知らない」と拒否する） | どちらかが違う |
| M-2 | 移行 SQL を `<new>` で生成し、SHA-256 を記録してレビューする。新しいイメージを発行する（4.1節の2） | SQL に ROLE・GRANT・DROP・TRUNCATE が想定外に入っている |
| M-3 | 移行前のバックアップを取り、隔離環境で復元して照合する（[backup-restore.md](backup-restore.md) 2〜5節）。API を止めてから取ると照合値が完全に一致する | 復元の不合格 |
| M-4 | public-api だけを止める：`docker compose -p nexus-edge-pg17 -f compose.pg17-edge.yaml stop public-api`（Caddy は残す。外からは 502） | — |
| M-5 | 移行 SQL を適用する（NexusInfra issue-8 資料の B2 と同じ形：稼働中の PG17 コンテナへの `docker exec -i --user postgres … psql -v ON_ERROR_STOP=1`、`PGOPTIONS='-c lock_timeout=5s'`。SQL の先頭で `SET ROLE nexus_owner`） | psql が0以外で終わる → 5節 L-3 |
| M-6 | 権限 SQL が変わったときだけ `grant-runtime.sql` を流す（API は止まっているのでロックの影響は無い） | psql が0以外 |
| M-7 | 移行履歴が `<new>` の一覧と一致することを確かめる：`SELECT "MigrationId" FROM "__EFMigrationsHistory" ORDER BY 1` | 一致しない |
| M-8 | 新しい digest で `up -d --wait`（4.1節の3と同じ） | healthy にならない → 5節 L-4 |
| M-9 | 6節で判定し、デプロイした commit・digest・移行 SQL の SHA-256・所要時間を記録する | 不合格 → 5節 L-4 |

**順序を入れ替えない。** 新しいイメージを先に起動すると G-1 で起動しない（D1）。古いイメージを動かしたまま移行すると、次の再起動で止まる（D5）。

## 5. ロールバックの判断

| # | 状況 | 戻し方 | リハーサル |
|---|---|---|---|
| L-1 | イメージだけの変更で不合格 | NexusInfra §11：私有 env を前の digest に戻して `up -d --wait` | D4 |
| L-2 | edge（Caddy・証明書）の不具合 | NexusInfra §11（edge の project だけを止める。ACME の volume は残す） | — |
| L-3 | 移行 SQL が途中で失敗した | API は止めたまま。EF の移行は1件ごとにコミットされるので、前半が残り得る。履歴を読んでどこまで入ったかを記録し、原因を直した**同じ SQL を流し直す**（G-3）か、M-3 のバックアップから**別の volume へ復元**して切り替えるかを判断する（切り替えは NexusInfra の R2、別の計画と承認） | — |
| L-4 | 移行は成功したが、新しいイメージが不合格 | **前のイメージには戻せない**（G-1、D5）。既定は **forward-fix**：同じ移行の一覧のまま直したイメージを作り、4.1節で出す。それまで API は止めたままにする。急ぐ場合だけ M-3 のバックアップから復元し、前の digest で起動する（M-3 の後に書かれた `visit_logs` は失われる） | D5 |
| L-5 | 配信の内容が誤っている | デプロイの問題ではない。Studio で新しい Release を作る（版は単調に増え、配信側に戻す操作は無い。[E2-5](decisions/E2-5-participant-data-delivery-v2.md) §2・§8）。iOS は小さい版を採用しない | — |
| L-6 | DB の内容が壊れた | [backup-restore.md](backup-restore.md) の復元と、NexusInfra の R2 | #71 |

**移行は戻さない。** Down を書かず、自動の逆移行もしない（G-4）。誤った移行は、それを打ち消す新しい移行として前へ直す。移行を書くときは、既存の列・表を消す変更と、それを使わなくなるコードの変更を別のリリースに分ける（使わなくなるリリースを先に出す）。

## 6. 成功と失敗の判定

| # | 確認 | 合格 | 失敗のときに見るもの |
|---|---|---|---|
| S-1 | public-api が healthy | `docker compose … ps` で healthy | `docker compose … logs public-api` に `Database migration history differs` → 順序の誤り（4.2節）。`must use the dedicated nexus_public login` → 秘密ファイル |
| S-2 | 外部 HTTPS の `/health` | 200 | Caddy のログ、証明書 |
| S-3 | DB を読む要求 `GET /api/v2/bundle` | 200 または 304（`If-None-Match`）。`Nexus-Bundle-*` が付く。最初の公開の前なら 404 `bundle-not-published` | 503 `bundle-unavailable` → DB 接続。500 `bundle-integrity` → 配信表の破損 |
| S-4 | 移行履歴 | M-7 と同じ | — |
| S-5 | PG17 のコンテナ ID・image・mount・volume が作業の前と同じ | NexusInfra §10 の4 | 一致しなければ止めて調べる |
| S-6 | ログに例外や秘密が出ていない | 起動後数分のログ | — |
| S-7 | 実機の iOS で bundle を取り直せる | 新しい `bundle_version`（変わっていなければ同じ版と最終確認日時の更新） | — |

`/health` の 200 だけで合格にしない（G-5、D7）。

## 7. iOS と公開サイトへの影響

- **iOS は止まっている間も使える**。保存済みの bundle を使い続け、取得に失敗しても版を戻さない（[E2-5](decisions/E2-5-participant-data-delivery-v2.md) §6 の2・4）。再試行は `Retry-After` と指数バックオフに従う（§6 の10）
- **iOS のアプリは戻せない**。App Store に出したビルドはサーバー側の都合で取り下げられないので、public-api と配信の契約は、出ている iOS の版が読める形を保つ。schema のメジャー版を上げる変更は、それを読める iOS が行き渡ってから出す（E2-5 §7）
- 公開サイトは止まっている間、サーバー状況を「応答なし」と表示する
- 移行を含むデプロイ（4.2節）は告知の対象。いつ・何分止めるかを事前に決める（運用の決定、P-6）

## 8. リハーサル（2026-11-15、使い捨て環境）

[`tools/database/rehearse-deploy.sh`](../tools/database/rehearse-deploy.sh) で D1〜D7 を通した。記録は [`docs/verification/deploy-rollback-2026-11-15/`](verification/deploy-rollback-2026-11-15/README.md)。

```sh
DOCKER_CONTEXT=colima-nexus-db-verify NEXUS_INFRA_DIR=../nexus-infra \
NEW_IMAGE=<今回の public-api> PREV_IMAGE=<前回の public-api> bash tools/database/rehearse-deploy.sh
```

本番でしか確かめられないこと（GHCR からの取得、`linux/amd64`、Caddy 経由、実データ量でのロックと所要時間）は含まない。

## 9. 本番で承認が必要な手順

| # | 手順 | 承認 |
|---|---|---|
| P-1 | 最初の導入（4.0節）：NexusInfra の承認 A・B・C と edge §10 | NexusInfra#6・#8・#17 の承認 |
| P-2 | `public-api-image.yml` の実行（環境 `public-api-image` の承認） | デプロイごと |
| P-3 | 私有 env の digest を変えて `up -d --wait`（4.1節） | デプロイごと |
| P-4 | 移行を含むデプロイ（4.2節 M-3〜M-9。M-3 は承認A と同じ扱い） | デプロイごと。SQL の全文と SHA-256 を添える |
| P-5 | ロールバック（5節）。L-1・L-2 は手順の中で判断してよいとするか、毎回承認とするか | 運用の決定 |
| P-6 | 移行を含むデプロイの停止時間と告知 | 運用の決定 |

## 10. 残っていること

- **起動時の確認を「完全一致」のまま保つか**（O-1、オーナーの判断）。今の形は安全側だが、列を足すだけの移行でも前のイメージに戻せない（L-4）。「DB の履歴が自分の一覧を含む」まで緩めると、足すだけの移行では前のイメージに戻せるようになる代わりに、移行を書く側に後方互換の規律が要る。本書は今の形を前提にしている
- NexusInfra の issue-8 資料 §1.2 の「入力が変わったら止める」は `apps/admin-api/Migrations` を見ている。#181 で `apps/nexus-data/Migrations` に移ったので、NexusInfra 側の修正が要る（本 PR では NexusInfra を変えていない）
- 監査チェーンの時刻の精度の不具合（[backup-restore.md](backup-restore.md) 6節）は、デプロイ後の確認に `audit-verify` を使えない理由にもなっている。修正は別の PR
- 本番の値（digest、platform、私有 env、停止時間）での手順の通し確認は、NexusInfra の承認の後
