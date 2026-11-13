# E8-7 r1: admin-api を v1.0 から取り除く方法

- 移行元ID: E8-7（C-4 の後続）/ 区分: E8 / Issue: [#72](https://github.com/m0o9l0v3/NexusMobile/issues/72)
- 関係: [E8-7 本番の CORS 許可オリジン](E8-7-production-cors-origins.md) の C-4、[E2-5 v2](E2-5-participant-data-delivery-v2.md) §8.1、[本番データベースの採用・運用方針](production-database.md)、#75（E8-8）、#77、PR #175（public-api の CORS）、PR #176（`apps/admin-web` の削除）、NexusInfra `docs/pg17-baseline.md`（契約B）・`docs/pg17-issue-8-production-apply.md`
- 起案日: 2026-11-14
- 判断者: リポジトリオーナー（技術的意思決定者）
- 判断日: 未定
- 状態: **起案**。§5 の判断を受けてから、§3 の手順を別の PR で行う。本書の PR はコードを変えない。本番への適用は NexusInfra の手順と別の承認による

## 0. 要約

2026-11-14 の C-4 で、管理ポータルと admin-api は v1.0 の本番に置かないと決めた。管理ポータルは PR #176 で削除する。admin-api は、public-api・`public-api.Tests`・`tools/database` が ProjectReference で **DB の型と移行** を借りているため、そのままでは消せない。

推奨は次のとおり（§3）。

1. **共有している型だけを新しいクラスライブラリ（仮名 `Nexus.Data`）へ移し、そのあと admin-api のホスト（コントローラー・認証・QR など）を削除する**（R1）。
2. **表と移行は残す**（E2-5 v2 §8.1 と同じ扱い）。移行履歴の2本を変えないので、`DatabaseReadiness`、NexusInfra の契約B、本番適用前のレビュー資料（Issue #8）を変えずに済む。admin 専用の表は、次に移行履歴が変わる機会にまとめて消す。
3. **hidden beta のコード（QR 発行・ワンタイムコード・`/q/{token}`）は admin-api と一緒に削除し、git の履歴から復元できるようにする**（H1）。ただし `CLAUDE.md` の「hidden beta としてコードを保全」と食い違うので、オーナーの判断が要る（§5 D-4）。

作業は2つの PR に分ける。1つ目は**移すだけ**で、移行 SQL の出力がバイト単位で変わらないことを確かめる。2つ目で admin-api を消す。どちらも PR #175・#176 のマージ後に始める。

## 1. 現状（2026-11-14 確認、develop `7121216`）

コードを読んで確かめた。ビルドやテストで確かめたものではない。

### 1.1 admin-api を参照しているもの

| 参照元 | 参照の仕方 |
|---|---|
| `apps/public-api/PublicApi.csproj` | `<ProjectReference Include="..\admin-api\AdminApi.csproj" />`。admin-api の `appsettings*.json` が publish に混ざらないよう、`ExcludeAdminHostSettings` ターゲットで取り除いている |
| `apps/public-api.Tests/PublicApi.Tests.csproj` | public-api と admin-api の両方を参照 |
| `tools/database/Nexus.Database.csproj` | admin-api と public-api の両方を参照 |
| `apps/public-api/Dockerfile` | `COPY apps/admin-api/` と、admin-api が埋め込む JSON Schema のための `COPY docs/schemas/` |

admin-api は `Microsoft.NET.Sdk.Web` のプロジェクトなので、public-api のイメージには admin-api の DLL と、その依存（`Microsoft.AspNetCore.Authentication.JwtBearer`、`QRCoder`、`JsonSchema.Net`、`NetTopologySuite`）も入る。

### 1.2 共有されている具体的な型

`using AdminApi.*` を持つファイルは、public-api に7つ（`Program.cs`、`Controllers/EventsController.cs`・`SpotsController.cs`・`LogsController.cs`、`Services/NearbyQueryService.cs`・`LogPersistenceService.cs`・`Delivery/ParticipantBundleRepository.cs`）、public-api.Tests に3つ（`LogIngestionTests.cs`・`SpotsControllerTests.cs`・`NearbyQueryServiceTests.cs`）、`tools/database/Program.cs` の1つ。

| 名前空間 | 型 | 使う側 | 切り出し先（推奨） |
|---|---|---|---|
| `AdminApi.Data` | `AdminDbContext`（13表の `DbSet`） | public-api（全コントローラー・サービス、`ParticipantBundleRepository` は接続だけ借りて `delivery` を SQL で読む）、テスト、tools | 共有ライブラリ |
| `AdminApi.Data` | `DatabaseReadiness`（本番の起動時検査：移行履歴の一致・実行ロールの権限・必要な表） | public-api、tools | 共有ライブラリ |
| `AdminApi.Data` | `DatabaseRuntimeConfiguration`（秘密ファイルの読み込み、接続文字列の選択、本番で既定の秘密を拒否） | public-api | 共有ライブラリ |
| `AdminApi.Migrations` | `20260905120000_AddMapDatasets`、`20260919120000_AddInitialPostgreSqlSchema`、`AdminDbContextModelSnapshot`、埋め込みリソース `InitialPostgreSqlSchema.sql` | tools（`script` で移行 SQL を出す）、`DatabaseReadiness`（`GetMigrations()`） | 共有ライブラリ |
| `AdminApi.Models` | 直接使うのは `Spot`・`Event`・`VisitLog`（public-api）、`Spot`・`Event`・`MapDataset`（tools）。`AdminDbContext` が13表すべてを持つので、モデルは全部（`Department`・`Exhibit`・`OcDay`・`OpenCampusTimeslot`・`TimeslotExhibit`・`QrIssue`・`OneTimeLoginCode`・`IssuedToken`・`RevokedToken`・`OpenCampusQrSnapshot` を含む）が要る | 共有ライブラリ |
| `AdminApi.Options` | `AuditLogOptions` | public-api、tools | 共有ライブラリ |
| `AdminApi.Options` | `RateLimitOptions`・`RateLimitPolicyOptions`・`RateLimitPolicies` | public-api（`LogsController` が `RateLimitPolicies.LogIngest` などを使う） | public-api（admin のポリシー `auth-login`・`code-redeem`・`qr-landing` を除く） |
| `AdminApi.RateLimiting` | `RateLimitingExtensions.AddNexusRateLimiting`（X-Forwarded-For の信頼範囲を含む） | public-api | public-api |
| `AdminApi.Services` | `AuditLogHasher`（監査ログのハッシュチェーン） | public-api（`LogPersistenceService`）、テスト、tools | 共有ライブラリ |

public-api が使わない admin 専用の型：`AdminAuthOptions`・`OneTimeCodeOptions`・`PortalOptions`・`QrIssueOptions`、`DbSeeder`、`Controllers/*`・`Dto/*`、`AuditLogVerificationService`・`JwtTokenService`・`OneTimeCodeService`・`OneTimeLoginService`・`QrCodeService`・`QrIssueLookupService`・`QrIssueTokenService`・`TokenRevocationService`・`TokenRevocationValidator`、`MapValidation/*`。

移すときに気をつける点：

- `AddInitialPostgreSqlSchema` は埋め込みリソースを **`"AdminApi.Migrations.InitialPostgreSqlSchema.sql"` という名前で** 読む。新しいプロジェクトでは `LogicalName` でこの名前を保つか、文字列を直す。
- EF が見つける移行は `[Migration]` 属性を持つ2本だけ。`20240920120000_InitialCreate` など他の7本は属性が無く、使われていない（2026-09 に「過去の移行を有効化しない」と決めたもの。`production-database-runbook.md`「初期スキーマの扱い」）。
- `__EFMigrationsHistory` に入るのは移行ID だけなので、名前空間や `DbContext` のクラス名を変えても履歴は変わらない。

### 1.3 表と、どれが admin 専用か

`InitialPostgreSqlSchema` と `AddMapDatasets` で13表を作る。

| 表 | 書く | 読む | admin-api を消した後 |
|---|---|---|---|
| `spots`・`events` | admin-api だけ | public-api（`nexus_public`、RLS で公開行だけ） | **書く人がいなくなる**（§1.7 の3） |
| `visit_logs`（参加者ログ・監査ログのハッシュチェーン） | **public-api**（`LogPersistenceService`） | public-api（前の hash）、admin-api（`/admin/logs`、`/admin/logs/verify`） | public-api が書き続ける。チェーンを**検証する手段**が無くなる（§1.7 の1） |
| `qr_issues`・`one_time_login_codes`・`issued_tokens`・`revoked_jti` | admin-api だけ（hidden beta と JWT 失効） | admin-api だけ | 使われなくなる |
| `oc_days`・`departments`・`exhibits`・`open_campus_timeslots`・`timeslot_exhibits` | admin-api だけ（開催日と QR のスナップショット） | admin-api だけ | 使われなくなる |
| `map_datasets` | だれも書かない（E2-5 v2 §8.1 で draft API を廃止済み） | — | 変わらない |

### 1.4 移行履歴と DB 権限

- **移行履歴**：`DatabaseReadiness` は「アプリが知る移行」と「適用済みの移行」が**完全に一致**することを起動の条件にしている。NexusInfra の契約B（`pg17-baseline.md`）も「履歴2本と完全一致」を前提にしている。`tools/database` の `script` が出す SQL の事前確認も、既知の履歴をこの2本に限っている。
- **権限**：`deploy/database/grant-runtime.sql` は `nexus_admin_app` に13表の CRUD を、`nexus_public` に `spots`・`events` の SELECT（RLS）と `visit_logs` の INSERT・3列の SELECT を与える。`DatabaseReadiness` は admin 側（`publicApi: false`）ではモデルの全表、public 側では `spots`・`events`・`visit_logs` の存在を確かめる。`tools/database verify` は `nexus_public` が admin 専用の表を読めないことも確かめる。
- **ロール**：本書の PG18 雛形（`init-roles.sh`）は `nexus_admin_app` を LOGIN で作り、`prepare-secrets.py` がその接続文字列を作る。NexusInfra の PG17 baseline（`01-roles.sql`）は **`nexus_admin_app` を NOLOGIN で作る**（PG17 では admin-api を動かさない前提）。
- **本番の状態**：NexusInfra の文書（`pg17-issue-8-production-apply.md`、2026-11-02）では、本番 PG17 への baseline（B1〜B3）は**レビュー中・未適用**で、適用する入力の SHA-256 を固定してレビューしている。本書ではこれ以上の確認はしていない（本番には接続していない）。
- `AddInitialPostgreSqlSchema.Down` は `NotSupportedException`。戻す手段はバックアップの復元だけ。

### 1.5 hidden beta のコード

QR 発行（`QrIssuesController`・`QrCodeService`・`QrIssueTokenService`）、`/q/{token}` の着地（`PublicQrController`・`QrIssueLookupService`）、ワンタイムコード（`EventOneTimeCodesController`・`OneTimeCodeRedemptionController`・`OneTimeCodeService`・`OneTimeLoginService`）、JWT の失効（`TokenRevocationController`・`TokenRevocationService`・`TokenRevocationValidator`）。すべて admin-api の中にあり、public-api からは使われていない。`CLAUDE.md` は「hidden beta としてコードを保全し、v1.0 の正式機能や主要導線には含めない」と書いている。`docs/v1.0-scope.md` は v1.0 に QR 認証・参加者別 QR を含めないと書いている。

### 1.6 開発環境

`docker-compose.yml` の開発環境では、**admin-api が起動時に `DbSeeder` で移行（PostgreSQL）または `EnsureCreated`（SQLite）を行い、サンプルを入れている**。public-api は Development では何もしない。admin-api を消すと、開発用の DB を作る経路が無くなる。public-api に移行や seed を足すことはできない（NexusInfra の `pg17-baseline.py manifest` が「public-api に `Migrate`・`EnsureCreated`・seed が無い」ことを静的に確かめている）。

### 1.7 見つかった食い違い・注意点

1. **監査ログ（`visit_logs`）は admin 専用の表ではない。** 書いているのは public-api で、ハッシュ（`AuditLogHasher`）も public-api が計算する。admin 専用なのは、チェーンを検証する `AuditLogVerificationService`（`/admin/logs/verify`）だけ。admin-api を消すと、チェーンを付けても検証する手段が無くなる（§5 D-5）。
2. **`MapDatasetValidator` は public-api で使われていない。** admin-api でも DI に登録しているだけで、どのコントローラーも使っていない（draft API は E2-5 v2 §8.1 で廃止済み）。§8.1 は「Studio のテストとの突合後に削除する」としており、まだ突合していない（§5 D-6）。public-api 側に残すものではない。
3. **`spots`・`events` を本番で書く人がいなくなる。** Studio が書くのは `delivery` スキーマで、`public.spots`・`public.events` ではない。iOS は `GET /api/v2/bundle` だけを使う。public-api の `/api/spots/public`・`/api/events/today`・`/api/nearby` は本番で常に空を返すことになる。これらを残すかは本書の範囲外とし、別に決める（§5 D-10、#131 の C-3 にも関わる）。
4. **public-api.Tests には、レート制限を無効にした場合と `KnownNetworks`（X-Forwarded-For の信頼範囲）のテストが無い。** admin-api-tests の `Disabled_DoesNotLimit` だけが前者を確かめている。
5. **PG18 雛形と PG17 baseline で `nexus_admin_app` の扱いが違う**（§1.4）。admin-api を置かないなら PG17 の NOLOGIN が実態に合う。

### 1.8 影響を受けるもの

| 対象 | 今の内容 | admin-api を消したとき |
|---|---|---|
| `deploy/database/compose.production.yml` | `admin-api` サービス（`NEXUS_ADMIN_IMAGE`、`Cors__Origins__0: ${NEXUS_ADMIN_ORIGIN:?…}`、秘密 `admin_connection`・`admin_login`・`signing_key`・`one_time_key`・`qr_key`、`127.0.0.1:5000`） | サービスと、それだけが使う秘密5つと変数2つを消す。`admin_password` は `init-roles.sh` がロールを作るのに使うので、D-7 の結論に従う |
| `docs/production-database-runbook.md` | 手順6「`up -d admin-api public-api` …管理APIの認証を確認」、設定表の `NEXUS_ADMIN_IMAGE`・`NEXUS_ADMIN_ORIGIN`、「両APIの `RateLimiting__KnownNetworks__0`」 | 手順6を `up -d public-api` にし、管理APIの認証の確認を外す。設定表の2行を消す |
| `docs/admin-operations.md` | admin-api の運用（初期アカウント、署名鍵、Swagger からの `admin.yaml` 出力）と DB 文書への案内 | 文書ごと消す。DB 文書（方針と構築手順）への案内は README に無いので、README へ移す |
| `packages/openapi/admin.yaml` | Admin API の OpenAPI 定義（使う側は admin-web だけで、PR #176 で消える） | 消す |
| `.github/workflows/ci.yml` | 46行 `dotnet test apps/admin-api-tests`、48行 `dotnet publish apps/admin-api`、106行 `docker build -f apps/admin-api/Dockerfile` | 3行を消す。共有ライブラリのテストの置き場（§3）に合わせて直す |
| `.github/workflows/public-api-image.yml` | 89行 公開前に `apps/admin-api-tests` を実行 | 消す（移したテストは public-api.Tests で走る） |
| `.gitlab-ci.yml`（DR 側の経路） | 48・50行の test・publish、81行のメッセージ「書き込みはadmin-apiの責務」、179行〜の `admin-api-image` ジョブ | 同じく消す・直す |
| `deploy/build-image.sh`、`deploy/README-production-images.md` | `admin-api` のイメージ名を受け付ける | 外す |
| `apps/public-api/Dockerfile` | `COPY apps/admin-api/`、`COPY docs/schemas/` | 共有ライブラリだけを COPY する。`docs/schemas/` は不要になる |
| `docker-compose.yml`（開発） | `admin-api` サービス | 消す。開発用の DB の作り方を D-8 で決める |
| `tools/database/prepare-secrets.py` | admin 用の秘密と接続文字列を作る | D-7 に合わせて直す |
| ドキュメント | `README.md`、`CLAUDE.md`、`docs/rate-limiting.md`（admin のポリシー3つ）、`docs/api-foundation.md`、`docs/security.md`（QR・JWT）、`docs/v1.0-scope.md` の hidden beta の記述 | 直す |
| Issue #75（E8-8：シード管理者パスワードが本番に入らないことを担保する） | 対象は admin-api の `DbSeeder` と既定パスワード `AdminPassword123!` | admin-api が無くなれば前提が消える（§6） |

admin-api-tests（48件）の行き先：

| テスト | 件数 | 対象 | 行き先 |
|---|---|---|---|
| `DatabaseRuntimeConfigurationTests` | 6 | 共有 | 共有ライブラリのテストへ移す |
| `MapDatasetTests` | 7 | `map_datasets` のモデルと移行 | 共有ライブラリのテストへ移す |
| `AuditLogChainTests.SaveChanges_SetsChainHashes` | 1 | `AuditLogHasher` | 共有ライブラリのテストへ移す |
| `AuditLogChainTests.VerifyAsync_DetectsTampering` | 1 | `AuditLogVerificationService` | D-5 に従う |
| `RateLimitingTests.Disabled_DoesNotLimit` | 1 | 共通のレート制限 | public-api.Tests に、ログ送信で同じことを確かめるテストとして書き直す（§1.7 の4） |
| `RateLimitingTests` の残り（`auth-login`・`code-redeem`・`/health`） | 3 | admin のポリシー。`/health` は public-api.Tests に同等あり | 消す |
| `HealthEndpointTests` | 1 | admin-api の `/health` | 消す |
| `DbSeederTests` | 1 | 開発用 seed | D-8 に従う |
| `MapDatasetValidatorTests` | 19 | `MapDatasetValidator` | D-6 に従う（public-api には移さない） |
| `OneTimeLoginServiceTests`・`QrIssueLookupServiceTests`・`TokenRevocationValidatorTests` | 3・4・1 | hidden beta | D-4 に従う（H1 ならコードと一緒に消す） |

PR #175 がマージされると、`apps/admin-api-tests/CorsConfigurationTests.cs`（3件）が増える。admin-api と一緒に消す。

## 2. 選択肢

### 2.1 どこまで取り除くか

| 案 | 内容 | 長所 | 短所・リスク |
|---|---|---|---|
| R0：コードは残し、本番に置かないだけ | C-4 の決定そのまま。何も消さない | 作業なし | public-api のイメージに admin のコードと JWT・QR の依存が入り続ける。CI が admin-api を build・test・docker build し続ける。本番雛形が admin のイメージと `NEXUS_ADMIN_ORIGIN` を必須にしたまま。文書が「管理 API がある」と読める。#75 の対応が残る |
| **R1：共有部分を切り出し、admin-api のホストを消す。表と移行は残す** | §1.2 の共有の型を共有ライブラリへ移し、admin-api（コントローラー・認証・hidden beta・CI・雛形）を消す | 本番に出るコードと実際の構成が一致する。public-api のイメージから admin の依存が抜ける。移行履歴を変えないので、DB・契約B・NexusInfra の承認待ちの資料に影響しない | 2つの PR の作業。開発用 DB の作り方を作り直す必要がある（D-8） |
| R2：R1 に加え、admin 専用の表を消す移行を足す | `qr_issues` など9表を DROP する3本目の移行を作る | DB も実態どおりになる | 移行履歴が3本になり、`DatabaseReadiness`・`tools/database` の既知の履歴・`verify`・`grant-runtime.sql`・契約B・NexusInfra の `pg17-baseline.py` とレビュー資料（Issue #8、SHA-256 を固定済み）を同時に直し、再検証が要る |
| R3：`InitialPostgreSqlSchema` を作り直し、admin の表を最初から作らない | 適用済みでない前提で、既存の移行を書き換える | 移行が2本のまま、表が減る | 適用済みの移行を書き換えることになる（検証用 DB・NexusInfra の隔離検証・レビュー資料の入力がすべて変わる）。本番が未適用だと確かめきれていない。**不可** |

### 2.2 共有部分の置き場と名前

| 案 | 内容 | 長所 | 短所・リスク |
|---|---|---|---|
| **L1：新しいクラスライブラリ（`Microsoft.NET.Sdk`）を作る** | 名前の候補は下の表。public-api・tools・テストはこれだけを参照する | 責務が「DB の形と移行」に限られる。Web の依存を持たない。public-api の書き込み禁止の検査（`public-api-readonly-check`）の対象外に、移行やモデルを置ける | プロジェクトが1つ増える |
| L2：public-api に取り込む | DbContext・移行・モデルを public-api に移す。tools は既に public-api を参照している | プロジェクトが増えない | 読み取り専用の API が、全表のモデルと移行を持つことになる。NexusInfra の `pg17-baseline.py manifest` と CI の書き込み検査の前提（public-api に移行・seed が無い）と合わない |
| L3：`tools/database` に取り込む | ツールを共有ライブラリにする | — | API が実行ファイルのプロジェクトを参照することになる。不自然 |

L1 の名前の候補：

| 名前 | 長所 | 短所 |
|---|---|---|
| **`Nexus.Data`** | 中身（DB の形と移行）をそのまま表す。範囲が狭く、後で広がりにくい | 将来のレイヤー構成（`CLAUDE.md`：`Nexus.Domain / Application / Infrastructure / Contracts`）に合わせるとき、改名が要る |
| `Nexus.Infrastructure` | 将来のレイヤー構成の名前と合う | その構成は未着手。名前が広く、DB 以外のものを入れたくなる |
| `Nexus.Persistence` | 意味は明確 | リポジトリのどこにも無い語で、将来の構成とも合わない |
| （`Nexus.Database` は不可） | — | `tools/database/Nexus.Database.csproj` と衝突する |

置き場所の候補は `apps/nexus-data/Nexus.Data.csproj`（今の `apps/public-api` と同じ並び）。

### 2.3 hidden beta のコード

| 案 | 内容 | 長所 | 短所・リスク |
|---|---|---|---|
| **H1：admin-api と一緒に削除し、git の履歴から復元できるようにする** | 削除直前のコミットを `CLAUDE.md` に書く（sensor-lab-ios と同じやり方）。必要ならタグ（例 `archive/admin-api-hidden-beta`）を付ける | 動かないコードを持ち続けない。JWT・QR の依存が消える。前例（sensor-lab-ios、admin-web）と同じ | `CLAUDE.md` の「コードを保全」を「履歴に保全」と読み替える改訂が要る。復元するときは共有ライブラリへの付け替えが要る |
| H2：`apps/admin-api` を残し、ソリューションと CI から外す（凍結） | ファイルは残すがビルドしない | ファイルを見ればある | 共有ライブラリへ移した後はビルドが通らなくなり、だれも直さないまま腐る。残っていることが「使える」と誤解される |
| H3：hidden beta のサービスだけ共有ライブラリへ移す | QR・ワンタイムコード・JWT 失効のサービスとテストを残す | テストが動き続ける | 呼ぶホストが無いコードを、本番の public-api のイメージに入れることになる。JWT・QR の依存も入る |

## 3. 推奨

1. **R1（共有部分を切り出し、admin-api のホストを消す）とする。表と移行は残す。**
2. **共有部分は L1 とし、名前は `Nexus.Data`、場所は `apps/nexus-data/` とする。** レート制限（`RateLimitingExtensions`・`RateLimitOptions`）は public-api だけが使うので、共有ライブラリではなく public-api へ移し、admin のポリシー3つを外す。
3. **hidden beta は H1 とする。** `CLAUDE.md` と `docs/v1.0-scope.md` の記述を「削除直前のコミットから復元できる」に改める。
4. **admin 専用の表（9表）と `map_datasets` の削除は、E2-5 v2 §8.1 と同じく単独では行わない。** 次に移行履歴が変わる機会（`spots.is_published` の廃止など）に、契約Bの改訂・再検証とまとめる。それまで表は空のまま残り、`nexus_public` からは読めない。

理由：
- 消したいのは「本番に置かないものがリポジトリと CI と本番雛形に残っていること」であり、DB の形ではない。表を残せば、DB・権限・NexusInfra の承認待ちの資料に何も波及しない。E2-5 v2 §8.1 が `map_datasets` で同じ判断をしている。
- 移すだけの PR と消す PR を分けると、1つ目は「移行 SQL の出力が変わらない」ことで機械的に確かめられる。レビューできるのが1人なので、確かめ方が単純な単位にする。
- `Nexus.Data` は中身に合った狭い名前で、未着手のレイヤー構成を先取りしない。

### 3.1 手順

**前提**：PR #175（CORS）と PR #176（admin-web の削除）がマージされていること。#175 は `apps/public-api/Program.cs`（CORS の部分）、`deploy/database/compose.production.yml`（public-api の節）、`apps/admin-api/appsettings.json`、`apps/admin-api-tests/CorsConfigurationTests.cs` を変える。下の PR-b は同じファイルの別の箇所（`Program.cs` の `using` とレート制限の登録、compose の admin-api の節）を変え、#175 が足すテストを消すので、#175 の後に作る。

**PR-a：共有ライブラリへ移す（振る舞いを変えない）**

1. `apps/nexus-data/Nexus.Data.csproj`（`Microsoft.NET.Sdk`、net8.0）を作り、`Nexus.sln` に足す。パッケージは EF Core・Sqlite・Npgsql の3つ。`Migrations/InitialPostgreSqlSchema.sql` を `LogicalName="AdminApi.Migrations.InitialPostgreSqlSchema.sql"` で埋め込む。
2. `git mv` で次を移す：`Data/AdminDbContext.cs`・`DatabaseReadiness.cs`・`DatabaseRuntimeConfiguration.cs`、`Migrations/` 全体（属性の無い7本も今は動かさずそのまま移す）、`Models/` 全体、`Options/AuditLogOptions.cs`、`Services/AuditLogHasher.cs`。**名前空間とクラス名は変えない**（`AdminApi.Data` のまま）。git が「移動」と判定でき、差分が読みやすい。
3. admin-api・public-api・public-api.Tests・tools/database が `Nexus.Data` を参照するようにする。この PR では admin-api はまだ残り、`Nexus.Data` を参照してビルドが通る。
4. 確かめること：`dotnet build Nexus.sln`、2つのテストプロジェクトが通る。`tools/database script` の出力が、移す前と**バイト単位で同じ**。

**PR-b：admin-api を消す**

1. `RateLimitingExtensions`・`RateLimitOptions` を public-api へ移し、admin のポリシー3つを外す。public-api と tests と tools から `AdminApi.csproj` への参照を消し、`PublicApi.csproj` の `ExcludeAdminHostSettings` を消す。`apps/public-api/Dockerfile` は `apps/nexus-data/` を COPY し、`apps/admin-api/` と `docs/schemas/` の COPY を消す。
2. §1.8 の表のテストを移す。行き先は public-api.Tests（`Data/` フォルダ）とする（テストプロジェクトを増やさない）。`Disabled_DoesNotLimit` 相当をログ送信で書き直す。
3. 開発用の DB の作り方（D-8）を `tools/database` のコマンドとして足し、`DbSeeder` を移す。`docker-compose.yml` から admin-api を消す。
4. `apps/admin-api`・`apps/admin-api-tests`・`packages/openapi/admin.yaml`・`docs/admin-operations.md` を消す。§1.8 の CI・雛形・ドキュメントを直す。削除直前のコミットを `CLAUDE.md` に書く。
5. 確かめること：build・test。public-api の publish 出力に `AdminApi.dll`・JWT・QRCoder が無い。`tools/database script` の出力が PR-a と同じ。隔離 PG で `tools/database verify` が通る（`nexus_admin_app` を使う部分は D-7 に従う）。

**PR-c（任意、D-3）：名前空間とクラス名を改める**（例 `AdminDbContext` → `NexusDbContext`、`AdminApi.*` → `Nexus.Data.*`）。移行ID は変わらないので履歴には影響しない。`InitialPostgreSqlSchema.sql` のリソース名をここで直すかは、PR-a の `LogicalName` と合わせて決める。

本番のイメージは PR-b で入力が変わるので、使う前に NexusInfra の手順でイメージの digest を検証し直す（`public-api-image.yml` の通常の経路）。

## 4. 選ばなかった案

| 案 | 選ばなかった理由 |
|---|---|
| R0：残すだけ | 本番に出ないコードと依存が public-api のイメージ・CI・本番雛形に残り続け、文書と構成の食い違いが解けない |
| R2：表も今消す | 移行履歴が変わり、契約B・NexusInfra の承認待ちの資料・`DatabaseReadiness` などを同時に直して再検証することになる。表を残す費用（空の表が9つ）に比べて重い。E2-5 v2 §8.1 の前例どおり、次の機会にまとめる |
| R3：既存の移行の作り直し | 適用・検証済みの入力を書き換える。不可 |
| L2：public-api に取り込む | 読み取り専用の API が移行と全表のモデルを持ち、NexusInfra の静的検査と CI の書き込み検査の前提に反する |
| L3：tools に取り込む | API が実行ファイルを参照する形になる |
| 名前 `Nexus.Infrastructure` | 未着手のレイヤー構成を先取りし、範囲が広い名前になる |
| H2：凍結して残す | ビルドできないまま残り、使えると誤解される |
| H3：サービスだけ残す | 呼ぶ側の無いコードと JWT・QR の依存を、本番の public-api に入れることになる |
| 移すと同時に改名する | 移動と改名が1つの差分に混ざり、「振る舞いを変えていない」ことを確かめにくい |

## 5. オーナーが決めること（未決事項）

| ID | 論点 | 推奨 | 決める前に確かめる事実 |
|---|---|---|---|
| D-1 | どこまで取り除くか | R1 | なし |
| D-2 | 共有ライブラリの名前と場所 | `Nexus.Data`、`apps/nexus-data/` | なし |
| D-3 | 名前空間・`AdminDbContext` を改名するか、いつするか | 改名するなら PR-c として別にする。急がない | なし |
| D-4 | hidden beta のコードの扱い | H1（削除し、履歴から復元できるようにする）。`CLAUDE.md`「hidden beta としてコードを保全」と `docs/v1.0-scope.md` を改める | 後続版で QR・ワンタイムコードを使う予定があるか |
| D-5 | 監査ログのハッシュチェーンを検証する手段 | `AuditLogVerificationService` を `Nexus.Data` に移し、`tools/database` に読み取り専用の検証コマンドを足す。テスト `VerifyAsync_DetectsTampering` も移す。要らないなら、チェーンを付ける理由を `docs/security.md` に書き直す | 本番で監査ログの改ざん検知を運用するか |
| D-6 | `MapDatasetValidator` と19件のテスト | E2-5 v2 §8.1 の「Studio のテストとの突合」を PR-b の前に済ませ、PR-b で削除する。突合が間に合わなければ、PR-b ではこの2ファイルだけ `tools/` 側に一時的に退避する | #77 と Studio へ移したテストの対応表 |
| D-7 | `nexus_admin_app` ロールと admin 用の秘密 | ロールと `grant-runtime.sql` は表と一緒に残す（R1）。PG18 雛形では PG17 baseline に合わせて NOLOGIN にし、`admin_connection`・`admin_login`・`signing_key`・`one_time_key`・`qr_key` を消す。`tools/database verify` で書き込みに使うロールは、使い捨て DB の中だけで LOGIN を与える | `verify` が `nexus_admin_app` で fixture を書いている箇所（`tools/database/Program.cs`）の置き換え先 |
| D-8 | 開発用の DB の作り方 | `tools/database` に Development 専用のコマンド（例 `dev-init`：SQLite は `EnsureCreated`、PostgreSQL は移行、のあとサンプル投入）を足し、`DbSeeder` と `DbSeederTests` を移す。public-api には足さない | なし |
| D-9 | #75（E8-8） | PR-b のマージ後、「admin-api と `DbSeeder` の本番経路が無くなったので不要」として閉じる。D-8 のコマンドは本番の接続を拒否すること（`verify` の `NEXUS_DB_DISPOSABLE` と同じ形）を受入条件にする | なし |
| D-10 | 書く人がいなくなる `spots`・`events` と、それを読む public-api の `/api/spots/public`・`/api/events/today`・`/api/nearby` | 本書では扱わない。#131 の C-3（公開サイトが `/health` 以外を使うか）と合わせて別に決める | 公開サイトと iOS がこれらを使うか |
| D-11 | admin 専用の9表と `map_datasets` を消す時期 | 次に移行履歴が変わる機会に、契約Bの改訂・再検証とまとめる（E2-5 v2 §8.1 と同じ） | 次の移行の予定（Studio の `spots.is_published` 廃止など） |

## 6. 採用後の作業と他の Issue への影響

| 対象 | 作業 |
|---|---|
| NexusMobile PR-a・PR-b（・PR-c） | §3.1 のとおり。PR #175・#176 のマージ後に始める |
| `docs/v1.0-scope.md`・`CLAUDE.md`・`README.md` | admin-api のコードを消したこと、hidden beta の扱い（D-4）、リポジトリ構成と技術スタックの表（「公開API：Admin DB を ProjectReference 共有」）を直す。PR-b に含める |
| `docs/production-database-runbook.md`・`docs/decisions/production-database.md` | 手順6と設定表（§1.8）。方針の「admin-api の実行ユーザーには必要な表へのCRUD権限」は、D-7 の結論に合わせて「admin-api を置く場合」と書き直す |
| `docs/rate-limiting.md`・`docs/security.md`・`docs/api-foundation.md` | admin のポリシー・QR・JWT の記述を外すか、履歴にあると書く |
| NexusInfra | R1 では移行履歴・権限・契約Bは変わらないので、PG17 baseline とレビュー資料（Issue #8）は変えなくてよい。public-api の新しいイメージの digest の検証は通常の手順で行う。D-11 のときに契約Bを改める |
| NexusStudio | 影響なし。D-6 の突合だけ Studio のテストを参照する |
| #75（E8-8） | D-9 |
| #77 | D-6 の突合の記録先 |
| #131 | D-10 |
| E7（管理ポータル） | 既に v1.0 の必須成果から外れている。未完了の Work item の扱いは `docs/v1.0-scope.md` のとおり個別に決める |
