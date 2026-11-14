# Nexus

> **開発の正本:** [GitHub repository](https://github.com/m0o9l0v3/NexusMobile)
> このGitLab repositoryはSecondary/DRバックアップです。通常の開発・Issue/PR管理はGitHubで行ってください。Git refsはVPSから約15分ごと、Issue・PR等のメタデータは毎時バックアップされます。GitLabへの直接pushやIssueの手編集は避けてください。

オープンキャンパス向けの総合支援プラットフォームです。参加者向け iOS アプリ（SwiftUI）・公開サイトと、それらを支える .NET の公開 API で構成されています。公開データの編集と公開は NexusStudio が担います。管理ポータル（旧 `apps/admin-web/`）と管理 API（旧 `apps/admin-api/`）は v1.0 の本番に置かないと決め（[E8-7 C-4](docs/decisions/E8-7-production-cors-origins.md)）、2026-11-14 に削除しました（admin-api は [E8-7 r1](docs/decisions/E8-7-r1-admin-api-removal.md)）。将来的には「Nexus AI Ecosystem」として、エージェント型コパイロット基盤へ発展させることを視野に入れた卒業研究プロジェクトです。

v1.0 の包含・除外とリリース条件は [`docs/v1.0-scope.md`](docs/v1.0-scope.md) を正とします。参加者向けアプリ機能は iOS に限定し、`web/` はアプリの告知・開発状況・サーバー状況・技術説明を掲載する公開サイトにします。iOS 限定の決定経緯は [GitHub Issue #7](https://github.com/m0o9l0v3/NexusMobile/issues/7)、公開サイトと QR パラメーターの挙動は [GitHub Issue #131](https://github.com/m0o9l0v3/NexusMobile/issues/131) を参照してください。

---

## リポジトリ構成

```
Nexus/
├── web/                      # 公開サイト（React + Vite + Tailwind、#131。トップ＋3ページ、作成中）
├── apps/
│   ├── nexus-data/           # DB の形・移行・起動時の DB 検査・監査ログのチェーン（Nexus.Data）
│   ├── public-api/           # 公開 API（ASP.NET Core 8）
│   ├── public-api.Tests/     # 公開 API テスト
│   └── nexus-ios/            # 現行 iOS アプリ（Swift / SwiftUI、Nexus.xcodeproj）
├── packages/
│   └── shared/               # 共通型・API クライアント（@nexus/shared）
├── openapi/                  # Public API OpenAPI 定義（public.yaml）
├── docs/                     # 設計・フェーズドキュメント
├── tools/database/           # 移行 SQL の出力・監査チェーンの検証・開発用 DB の作成・使い捨て DB での検証
├── mock-api/                 # json-server モック
├── docker-compose.yml        # ローカル Docker 環境
└── Nexus.sln                 # Visual Studio ソリューション
```

---

## Apps 詳細

### 公開サイト（`web/`）

React 18 + Vite + Tailwind CSS v4 で構築する公開 Web です（#131）。次を掲載します。参加者向けアプリの代替機能は提供しません。

- アプリ（iOS）の告知
- 開発状況
- サーバー状況
- 開発に伴う技術説明

方針転換前の参加者向け PWA は 2026-10-25 に削除しました。現在はトップ＋3ページのマルチページ構成を作っているところで、トップ（アプリの告知）・開発状況・サーバー状況ができています。決定と残りは [`docs/overview.md`](docs/overview.md) と #131 にあります。

---

### 公開 API（`apps/public-api/`）

ASP.NET Core 8 Web API。認証なし。DB の型と移行は `apps/nexus-data`（`Nexus.Data`）を ProjectReference で使い、書き込みは参加者ログ（`visit_logs`）の INSERT だけです。ログ受信は Serilog でバックグラウンドキューに流し込みます。

**エンドポイント**

| メソッド | パス | 説明 |
|----------|------|------|
| GET | `/api/v2/bundle` | 参加者向け公開データ（地点・地図）の bundle（E2-5、ETag・304 対応） |
| GET | `/api/spots/public` | 公開済みスポット一覧 |
| GET | `/api/spots/by-code/{code}` | QR コードからスポット取得 |
| GET | `/api/nearby` | 位置情報（緯度・経度・半径）でスポット距離順ソート |
| GET | `/api/events/today` | 当日（JST）の公開イベント一覧 |
| POST | `/api/logs` | 参加者ログ受信（1 件） |
| POST | `/api/logs/batch` | 参加者ログ受信（最大 50 件一括） |
| GET | `/health` | ヘルスチェック |

- Swagger UI（Development）: `http://localhost:5001/swagger`

---

### iOS アプリ（`apps/nexus-ios/`）

SwiftUI 製の現行 iOS アプリです。`Nexus.xcodeproj` の共有 Scheme `Nexus` で起動・テストします。タブは **Home / Map / 案内 / 探す** の4つです。各タブの識別子と表示名は `Nexus/Application/AppTab.swift`、アプリシェルは `Nexus/Application/NexusAppShell.swift` に定義されています。

**Xcode の主なビルド設定**

| 設定 | 値 |
|------|----|
| iOS Deployment Target | 18.0 |
| Bundle Identifier | `dev.nexusapp.mobile` |
| 対象端末 | iPhone |
| Development Team | `NEXUS_DEVELOPMENT_TEAM` で指定 |

旧 Expo / React Native アプリ `apps/mobile-ios/` は削除し、現行 iOS アプリを `apps/nexus-ios/` に一本化しました。

Phase 0 センサー検証アプリ `apps/sensor-lab-ios/` は試験段階の構想にとどまったため、2026-10-24 に凍結して削除しました。再開する場合は git 履歴（削除直前は `4de2e6a`）から復元します。

---

### 共有パッケージ（`packages/shared/`）

屋内推定位置（`EstimatedIndoorPosition`）の型だけを含む JavaScript パッケージです。静的な経路デモ API 用の型とクライアントは #21 で削除しました。現行 SwiftUI アプリは Swift のモデルを使い、このパッケージには依存しません。

---

## ローカル開発

### 前提バージョン

- Node.js 20+
- .NET SDK 8.0+
- Xcode 16 以降（SwiftUI iOS アプリのビルド・実行）
- PostgreSQL 15（Docker 利用の場合は不要）

### 公開サイト

```bash
cd web
npm install
npm run dev        # http://localhost:5176
```

- 型チェック: `npm run typecheck`、ビルド: `npm run build`、プレビュー: `npm run preview`
- 現在のコードは環境変数を参照しません（public-api を使うときに #131 で定めます）。

### 開発用の DB

開発用の DB の作成（SQLite は `EnsureCreated`、PostgreSQL は移行）とサンプルの投入は `tools/database` の `dev-init` で行います。本番・検証用の DB は拒否します（`NEXUS_DEV_DATABASE=1` が必要、手元のホストだけ、本番雛形のロールがある DB は不可）。

```bash
# SQLite（public-api の appsettings.Development.json と同じファイル）
NEXUS_DEV_DATABASE=1 NEXUS_DEV_CONNECTION="Data Source=apps/public-api/admin-dev.db" \
  dotnet run --project tools/database/Nexus.Database.csproj -- dev-init
```

### 公開 API

```bash
cd apps/public-api
dotnet run         # http://localhost:5001（先に「開発用の DB」を作る）
```

### iOS アプリ

Xcode で `apps/nexus-ios/Nexus.xcodeproj` を開き、Scheme `Nexus` を選んで実行します。シミュレーター向けビルドは次のとおりです。

```bash
xcodebuild -project apps/nexus-ios/Nexus.xcodeproj -scheme Nexus -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build
```

テストは利用可能な iPhone Simulator の UDID を指定して実行します。

```bash
xcodebuild -project apps/nexus-ios/Nexus.xcodeproj -scheme Nexus -destination 'platform=iOS Simulator,id=<SIMULATOR_UDID>' test
```

Archive / TestFlight 配布では、Xcode の `NEXUS_DEVELOPMENT_TEAM` と署名設定が必要です。Bundle Identifier と iOS Deployment Target は Xcode プロジェクトのビルド設定で管理します。

### テスト

```bash
# 公開 API・Nexus.Data のユニットテスト・OpenAPI 契約テスト
dotnet test apps/public-api.Tests

# 地図データの validator（NexusStudio との突合までの一時的な退避先。tools/map-validation-legacy/README.md）
dotnet test tools/map-validation-legacy/MapValidationLegacy.Tests.csproj
```

---

## Docker Compose

バックエンド（Public API / PostgreSQL）をまとめて起動します。

初回のみ、Secret（DB パスワード・監査ログ HMAC 鍵）を `.env` に生成します。値は `openssl rand` で作られ、リポジトリには含まれません。

```bash
tools/dev-secrets.sh
docker-compose up --build
```

DB の作成とサンプルの投入は、postgres が起動してから手元で行います（`.env` の `NEXUS_DEV_DB_PASSWORD` を使う）。

```bash
set -a; . ./.env; set +a
NEXUS_DEV_DATABASE=1 NEXUS_DEV_CONNECTION="Host=localhost;Port=5432;Database=nexus_admin;Username=nexus;Password=$NEXUS_DEV_DB_PASSWORD" \
  dotnet run --project tools/database/Nexus.Database.csproj -- dev-init
```

未生成のまま起動すると、必須変数の未設定エラーで停止します。Compose ファイルはリポジトリ直下の `docker-compose.yml` のみです。

**既存のローカル DB ボリュームがある場合**: 旧 Compose は DB パスワードを `nexus_password` で初期化済みで、`POSTGRES_PASSWORD` は空のボリュームにしか効かないため、そのままでは API が認証エラーになります。次のどちらかで移行してください。

```bash
# A) 開発データを捨ててよい場合: ボリュームごと作り直す
docker-compose down -v && docker-compose up --build

# B) データを残す場合: 新しい .env の値でロールのパスワードを更新する
docker-compose up -d postgres
docker-compose exec -T postgres sh -c 'psql -U nexus -d nexus_admin -v pw="$POSTGRES_PASSWORD"' <<< "ALTER ROLE nexus PASSWORD :'pw';"
docker-compose up --build
```

削除した `docker/docker-compose.yml` を使っていた場合、ボリューム名は `docker_nexus_admin_data`（プロジェクト名 `docker`）です。直下の定義に切り替えると既定のプロジェクト名が変わり、旧データを参照できません。上記の `docker-compose` を、すべて `docker-compose -p docker` に読み替えて実行してください（データを残す場合）。

| サービス | ポート | 説明 |
|----------|--------|------|
| public-api | 5001 | 公開 API |
| postgres | 5432 | PostgreSQL 15 |

---

## 環境変数

`.env.example` を `.env` にコピーして編集してください。

**公開サイト（`web/`）**

現在のコードは環境変数を参照しません。public-api を使うときに定めます（#131）。

**SwiftUI iOS アプリ（`apps/nexus-ios/`）**

ビルド設定は `Nexus.xcodeproj/project.pbxproj` で管理します。Signing に使用する Development Team は `NEXUS_DEVELOPMENT_TEAM` を指定します。

---

## OpenAPI

| ファイル | 対象 |
|----------|------|
| `openapi/public.yaml` | Public API（source of truth はコードから生成） |

YAML をコードから再生成する例:

```bash
dotnet tool install --global Swashbuckle.AspNetCore.Cli

swagger tofile --yaml ./apps/public-api/bin/Debug/net8.0/PublicApi.dll v1 \
  > ./openapi/public.yaml
```

---

## セキュリティ

- **JWT・QR ワンタイムコード**: 管理 API と hidden beta（QR 発行・ワンタイムコード・`/q/{token}`）は 2026-11-14 に削除しました（[E8-7 r1](docs/decisions/E8-7-r1-admin-api-removal.md)）。コードは `fb539f7` に残っています。`revoked_jti` などの表は移行履歴を変えないため残しています（空のまま）。
- **監査ログチェーン**: ログに `prev_hash`（前レコードの HMAC-SHA256）を連鎖させ、改ざん検知を可能にします。検証は `tools/database` の `audit-verify`（読み取り専用）で行います（`docs/security.md`）。
- **Secret 管理**: ローカル Compose は `tools/dev-secrets.sh` が生成する `.env`、本番は Compose secrets + `*File` 設定（`deploy/database/compose.production.yml`）で注入します。`appsettings.json` の `CHANGE_ME_TO_A_LONG_RANDOM_SECRET` は開発用プレースホルダーで、本番（非 Development）では起動時に拒否されます。

---

## ドキュメント

| ファイル | 内容 |
|----------|------|
| `docs/v1.0-scope.md` | v1.0 の製品境界・必須成果・対象外・リリース条件の正本 |
| `docs/nexus-ai-ecosystem.md` | AI エコシステム全体方針・フェーズロードマップ |
| `docs/design-rules.md` | UI デザインルール（余白・角丸・影・タイポ。iOS は SF Pro、記載のないことは Apple HIG） |
| `docs/security.md` | セキュリティ設計メモ |
| `docs/decisions/production-database.md` | 本番データベースの採用・運用方針（構築・権限・バックアップ・復旧・更新の正） |
| `docs/production-database-runbook.md` | 本番 DB の構築・検証手順 |
| `docs/overview.md` | 公開サイト（`web/`）の方針・状況・未決事項 |
| `docs/branch-policy.md` | ブランチ命名・復旧データ・統合後削除の運用方針 |
| `docs/phase1/route-ui-event-contract.md` | Phase 1 ルート表示 UI イベント契約書 |
| `docs/phase1/route-ui-next-tasks.md` | Phase 1 次タスク方針 |
| `docs/expo-sdk-54-migration.md` | 旧Expo SDK移行の履歴（アーカイブ） |
| `web/README.md` | 公開サイトの概要と開発コマンド |

---

## TODO / 今後の計画

- [ ] Phase 1: ルート表示 UI 強化（ステップ案内・フロア跨ぎ・逸脱検知）
- [ ] Phase 1: 管理コンソールへのオペレーターハンドオフ機能
- [ ] Playwright などで E2E テスト追加
- [ ] Lighthouse / A11y 改善（画像最適化・コントラスト・フォーカス表示）
- [ ] iOS アプリの QR スキャン UX 強化（連続読み取り・履歴・ガイド）
- [ ] ログ集約と分析ダッシュボード実装
- [ ] 3D/AR 用 Spot フィールド拡張

---
