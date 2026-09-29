# Nexus

> **開発の正本:** [GitHub repository](https://github.com/m0o9l0v3/NexusMobile)
> このGitLab repositoryはSecondary/DRバックアップです。通常の開発・Issue/PR管理はGitHubで行ってください。Git refsはVPSから約15分ごと、Issue・PR等のメタデータは毎時バックアップされます。GitLabへの直接pushやIssueの手編集は避けてください。

オープンキャンパス向けの総合支援プラットフォームです。参加者向け iOS アプリ・イベント告知 Web LP・管理ポータルと、それらを支える 2 本の .NET API で構成されています。将来的には「Nexus AI Ecosystem」として、エージェント型コパイロット基盤へ発展させることを視野に入れた卒業研究プロジェクトです。

v1.0 の包含・除外とリリース条件は [`docs/v1.0-scope.md`](docs/v1.0-scope.md) を正とします。参加者向けアプリ機能は iOS に限定し、`web/` はイベント告知・当日案内・iOS アプリへの導線を担う LP へ再構成します。この決定経緯は [GitHub Issue #7](https://github.com/m0o9l0v3/NexusMobile/issues/7)、LP の実装と QR パラメーターの挙動は [GitHub Issue #81](https://github.com/m0o9l0v3/NexusMobile/issues/81) を参照してください。

---

## リポジトリ構成

```
Nexus/
├── web/                      # イベント告知 LP（React + Vite + Tailwind、#81 で再構成）
├── apps/
│   ├── admin-web/            # 管理ポータル（React + Vite）
│   ├── admin-api/            # 管理 API（ASP.NET Core 8）
│   ├── admin-api-tests/      # 管理 API ユニットテスト
│   ├── public-api/           # 公開 API（ASP.NET Core 8）
│   ├── public-api.Tests/     # 公開 API テスト
│   ├── mobile-ios/           # iOS アプリ（Expo + React Native）
│   └── sensor-lab-ios/       # Phase 0 センサー検証アプリ（Swift / SwiftUI）
├── packages/
│   ├── shared/               # 共通型・API クライアント（@nexus/shared）
│   └── openapi/              # Admin API OpenAPI 定義（admin.yaml）
├── openapi/                  # Public API OpenAPI 定義（public.yaml）
├── docs/                     # 設計・フェーズドキュメント
├── mock-api/                 # json-server モック
├── docker-compose.yml        # ローカル Docker 環境
└── Nexus.sln                 # Visual Studio ソリューション
```

---

## Apps 詳細

### イベント告知 LP（`web/`）

React 18 + Vite + Tailwind CSS v4 で構築する公開 Web です。v1.0 では参加者向けアプリの代替機能を提供せず、次の役割に限定します。

- イベント告知と当日案内
- iOS アプリのダウンロード・利用導線
- `GET /api/events/today` を用いた、当日イベント一覧に必要な範囲の動的表示

現在の `web/` には Home / Map / Events、AI サポート、ログ送信など、方針転換前の参加者向け PWA プロトタイプが残っています。これらは v1.0 の正式な公開仕様ではありません。デザイン資産やコンポーネントの再利用範囲、公開ルート、API 利用範囲は #81 で棚卸し・実装します。

QR パラメーターの着地点、有効・無効値、未指定時の挙動も #81 で定義します。既存プロトタイプの `?code=XXXX` によるスポット表示を、LP の確定仕様として扱わないでください。

---

### 管理ポータル（`apps/admin-web/`）

React 18 + Vite + Tailwind CSS v4 + MUI v5 + TanStack Query の SPA です。

以下は現行実装の一覧です。QR 発行、ワンタイムコード、チェックイン関連の表示・エンドポイントは hidden beta であり、v1.0 の正式機能や主要導線には含めません。

**ページ**

| ページ | 説明 |
|--------|------|
| Dashboard | チェックイン数・混雑スポット等の KPI、折れ線/棒グラフ |
| Events | イベント CRUD・イベント別 QR 発行管理 |
| QR Issue | QR コード発行ウィザード（4 ステップ） |
| Crowd Analysis | 混雑状況分析（プレースホルダー） |
| Logs | 参加者ログ一覧 |

- 開発サーバー: `http://localhost:5176`
- Admin API 型は `openapi-typescript` で自動生成（`npm run generate:api`）

---

### 管理 API（`apps/admin-api/`）

ASP.NET Core 8 Web API。JWT 認証（jti 管理つきトークン失効）、Serilog、EF Core（SQLite / PostgreSQL 切替可）。

**エンドポイント（抜粋）**

| メソッド | パス | 説明 |
|----------|------|------|
| POST | `/admin/auth/login` | 管理者ログイン（JWT 発行） |
| POST | `/admin/tokens/revoke` | JWT 個別失効（jti 指定） |
| POST | `/admin/tokens/revoke-user` | ユーザー単位一括失効 |
| GET/POST/PUT/DELETE | `/admin/spots` | スポット CRUD |
| GET/POST/PUT/DELETE | `/admin/events` | イベント CRUD |
| GET/POST/PUT/DELETE | `/admin/oc-days` | 開催日 CRUD |
| GET/POST | `/admin/qr-issues` | QR 発行・一覧 |
| POST | `/admin/qr-issues/{id}/revoke` | QR 失効 |
| POST | `/admin/one-time-codes/generate` | ワンタイムログインコード生成 |
| POST | `/admin/one-time-login/redeem` | ワンタイムコード引換（訪問者 JWT 発行） |
| GET | `/admin/logs` | 参加者ログ直近 100 件 |

- Swagger UI（Development）: `http://localhost:5000/swagger`
- デフォルト管理者: ユーザー名 `admin` / パスワード `AdminPassword123!`
- 起動時に EF Core マイグレーションを自動適用し、Spots / Events / OcDays のサンプルデータをシード

---

### 公開 API（`apps/public-api/`）

ASP.NET Core 8 Web API。認証なし。Admin DB を読み取り専用で共有しています（ProjectReference 経由）。ログ受信は Serilog でバックグラウンドキューに流し込みます。

**エンドポイント**

| メソッド | パス | 説明 |
|----------|------|------|
| GET | `/api/navigation/spots` | ナビゲーション用スポット一覧 |
| GET | `/api/navigation/spots/{id}` | ナビゲーション用スポット詳細 |
| GET | `/api/spots/public` | 公開済みスポット一覧 |
| GET | `/api/spots/by-code/{code}` | QR コードからスポット取得 |
| GET | `/api/nearby` | 位置情報（緯度・経度・半径）でスポット距離順ソート |
| GET | `/api/events/today` | 当日（JST）の公開イベント一覧 |
| GET | `/api/floors` | フロアマップ定義一覧 |
| GET | `/api/routes` | スポット間ルート（`?from=&to=`） |
| POST | `/api/logs` | 参加者ログ受信（1 件） |
| POST | `/api/logs/batch` | 参加者ログ受信（最大 50 件一括） |
| GET | `/health` | ヘルスチェック |

- Swagger UI（Development）: `http://localhost:5001/swagger`

---

### iOS アプリ（`apps/mobile-ios/`）

Expo SDK 54 + React Native 0.81 + expo-router v6。`@nexus/shared` パッケージ経由で型と API クライアントを共有します。

**画面**

- Home（`app/index.tsx`）: ヒーロー・スポットカード
- Map（`app/map.tsx`）: インタラクティブマップ、経路案内
- Events（`app/events.tsx`）: イベント一覧

---

### Sensor Lab（`apps/sensor-lab-ios/`）

Swift / SwiftUI 製の Phase 0 技術検証アプリ。`CMAltimeter` で気圧・相対高度をリアルタイム取得し、移動平均フィルタで上昇/下降/停止を判定して CSV エクスポートします。本番 Nexus への屋内階層移動検知ロジック移植に向けた前段階の実機検証ツールです。iPhone 実機が必須です。

---

### 共有パッケージ（`packages/shared/`）

Spot / FloorMap / Route などの共通型と `createNavigationApiClient` を提供します。mobile-ios から `@nexus/shared` としてファイル参照（`file:../../packages/shared`）で利用します。

---

## ローカル開発

### 前提バージョン

- Node.js 20+
- .NET SDK 8.0+
- PostgreSQL 15（Docker 利用の場合は不要）

### イベント告知 LP

```bash
cd web
npm install
npm run dev        # http://localhost:5176
```

- 型チェック: `npm run typecheck`、ビルド: `npm run build`、プレビュー: `npm run preview`
- Web の実装が参照する環境変数は `VITE_API_BASE_URL` です。

### 管理ポータル

```bash
cd apps/admin-web
npm install
npm run dev        # http://localhost:5176
```

Admin API の型定義を再生成する場合:

```bash
npm run generate:api
```

### 管理 API

```bash
cd apps/admin-api
dotnet run         # http://localhost:5000
```

開発環境は SQLite を使用します（`appsettings.Development.json`）。

### 公開 API

```bash
cd apps/public-api
dotnet run         # http://localhost:5001
```

### iOS アプリ

```bash
cd apps/mobile-ios
npm install
npm run start      # Expo 開発サーバー起動

# iOS シミュレーター（macOS + Xcode 必須）
npm run ios
```

実機確認時は `.env` に以下を設定してください。

```
EXPO_PUBLIC_API_BASE_URL=http://<PCのLAN IP>:5001
```

### テスト

```bash
# 管理 API ユニットテスト（OneDrive 配下は C:\Work\Nexus にコピーして実行）
dotnet test apps/admin-api-tests

# 公開 API ユニットテスト・OpenAPI 契約テスト
dotnet test apps/public-api.Tests
```

---

## Docker Compose

バックエンド 3 サービス（Admin API / Public API / PostgreSQL）をまとめて起動します。

初回のみ、Secret（DB パスワード・JWT 署名鍵・監査ログ HMAC 鍵）を `.env` に生成します。値は `openssl rand` で作られ、リポジトリには含まれません。

```bash
tools/dev-secrets.sh
docker-compose up --build
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

| サービス | ポート | 説明 |
|----------|--------|------|
| admin-api | 5000 | 管理 API |
| public-api | 5001 | 公開 API |
| postgres | 5432 | PostgreSQL 15 |

---

## 環境変数

`.env.example` を `.env` にコピーして編集してください。

**イベント告知 LP（`web/`）**

| 変数 | デフォルト | 説明 |
|------|-----------|------|
| `VITE_API_BASE_URL` | —（未設定時は同一オリジン） | 公開 API の URL |

**管理ポータル（`apps/admin-web/`）**

| 変数 | デフォルト | 説明 |
|------|-----------|------|
| `VITE_ADMIN_API_BASE_URL` | `http://localhost:5000` | 管理 API の URL |
| `VITE_PARTICIPANT_BASE_URL` | `http://localhost:4173` | 公開 Web の URL（LP・QR 側の扱いは #81 で確定） |

**iOS アプリ（`apps/mobile-ios/`）**

| 変数 | 説明 |
|------|------|
| `EXPO_PUBLIC_API_BASE_URL` | 公開 API の URL（実機は LAN IP を使用） |

---

## OpenAPI

| ファイル | 対象 |
|----------|------|
| `openapi/public.yaml` | Public API（source of truth はコードから生成） |
| `packages/openapi/admin.yaml` | Admin API（source of truth） |

YAML をコードから再生成する例:

```bash
dotnet tool install --global Swashbuckle.AspNetCore.Cli

swagger tofile --yaml ./apps/admin-api/bin/Debug/net8.0/AdminApi.dll v1 \
  > ./packages/openapi/admin.yaml

swagger tofile --yaml ./apps/public-api/bin/Debug/net8.0/PublicApi.dll v1 \
  > ./openapi/public.yaml
```

---

## セキュリティ

- **JWT 失効**: 発行時に `jti` を記録し、失効対象を `revoked_jti` テーブルで管理。ミドルウェアが全リクエストで失効チェックを行います。
- **QR ワンタイムコード**: HMAC でハッシュ化して DB 保存。引換後は無効化し、イベント当日 23:59:59 JST で期限切れ。
- **監査ログチェーン**: ログに `prev_hash`（前レコードの HMAC-SHA256）を連鎖させ、改ざん検知を可能にします。
- **Secret 管理**: ローカル Compose は `tools/dev-secrets.sh` が生成する `.env`、本番は Compose secrets + `*File` 設定（`deploy/database/compose.production.yml`）で注入します。`appsettings.json` の `CHANGE_ME_TO_A_LONG_RANDOM_SECRET` は開発用プレースホルダーで、本番（非 Development）では起動時に拒否されます。

---

## ドキュメント

| ファイル | 内容 |
|----------|------|
| `docs/v1.0-scope.md` | v1.0 の製品境界・必須成果・対象外・リリース条件の正本 |
| `docs/nexus-ai-ecosystem.md` | AI エコシステム全体方針・フェーズロードマップ |
| `docs/design-rules.md` | UI デザインルール（余白・角丸・影・タイポ） |
| `docs/security.md` | セキュリティ設計メモ |
| `docs/overview.md` | Web LP 方針・移行状況・API 利用境界 |
| `docs/branch-policy.md` | ブランチ命名・復旧データ・統合後削除の運用方針 |
| `docs/phase0/validation-plan.md` | Phase 0 Sensor Lab 技術検証計画書 |
| `docs/phase1/route-ui-event-contract.md` | Phase 1 ルート表示 UI イベント契約書 |
| `docs/phase1/route-ui-next-tasks.md` | Phase 1 次タスク方針 |
| `docs/expo-sdk-54-migration.md` | Expo SDK 51 → 54 移行メモ |
| `web/DESIGN_SYSTEM.md` | デザインシステム詳細 |
| `web/IMPLEMENTATION_GUIDE.md` | フロントエンド実装ガイド |
| `web/BROWSER_COMPATIBILITY.md` | ブラウザ互換性メモ |

---

## TODO / 今後の計画

- [ ] Phase 1: ルート表示 UI 強化（ステップ案内・フロア跨ぎ・逸脱検知）
- [ ] Phase 1: 管理コンソールへのオペレーターハンドオフ機能
- [ ] Sensor Lab の屋内階層移動検知ロジックを mobile-ios に移植
- [ ] Playwright などで E2E テスト追加
- [ ] Lighthouse / A11y 改善（画像最適化・コントラスト・フォーカス表示）
- [ ] iOS アプリの QR スキャン UX 強化（連続読み取り・履歴・ガイド）
- [ ] ログ集約と分析ダッシュボード実装
- [ ] 3D/AR 用 Spot フィールド拡張

---

## Expo Go 接続トラブル

Expo Go から Metro サーバーへ接続できない場合は以下を確認してください。

1. PC とスマホを同じ Wi-Fi に接続する（VPN・ゲスト Wi-Fi・クライアント分離は失敗する場合があります）。
2. LAN または Tunnel を明示して起動する。

   ```bash
   npx expo start --lan
   # LAN が届かない場合
   npx expo start --tunnel
   ```

3. QR コードの URL が `exp://<PCのLAN IP>:8081` になっていることを確認する（`localhost` や WSL 内部の `127.0.0.1` は実機から到達できません）。
4. ファイアウォールで Metro（ポート 8081）の受信を許可する。
5. キャッシュが残る場合は Expo Go を完全終了後に `npx expo start --clear --lan` を実行する。

WSL / Docker 上で Metro を起動している場合は `--tunnel` を使うか、ホスト OS 側で Expo を起動してください。API も実機から参照する場合は `.env` の `EXPO_PUBLIC_API_BASE_URL` に `localhost` ではなく LAN IP を指定してください。
