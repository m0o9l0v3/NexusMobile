---

# Nexus 管理プラットフォーム（MVP）

このリポジトリには、Nexus の管理用ポータル（Admin Portal）と管理用 API（Admin API）が含まれています。

## モノレポ構成

```text
/apps
  /admin-web          React 管理ポータル（Vite + TypeScript + MUI）
  /admin-api          ASP.NET Core 管理 API（.NET 8）
/packages
  /openapi            OpenAPI 仕様
/docs                 運用ノート
/docker               ローカル開発用 Docker Compose
```

## 必要要件

* Node.js 20 以上
* .NET 8 SDK
* Docker（PostgreSQL を使う場合は任意）

## ローカル開発

### 1) PostgreSQL + Admin API を起動（Docker）

### Dockerなしで開発（SQLite）
1) Admin API を起動
```bash
cd apps/admin-api
$env:ASPNETCORE_ENVIRONMENT="Development"
dotnet run
```

2) Admin Portal を起動
```bash
cd apps/admin-web
npm install
npm run dev
```

SQLite の開発用 DB は `apps/admin-api/admin-dev.db` に作成されます。

### 1) Start PostgreSQL + Admin API (Docker)
```bash
cd docker
docker-compose up --build
```

API は `http://localhost:5000` で利用できます。
Swagger UI は Development 環境で `http://localhost:5000/swagger` から参照できます。

### 2) 管理ポータルを起動

```bash
cd apps/admin-web
npm install
npm run dev
```

`http://localhost:5173` を開いてください。

### 3) 環境変数

`.env.example` を `.env` にコピーし、以下を調整してください：

* `VITE_ADMIN_API_BASE_URL`
* `VITE_PARTICIPANT_BASE_URL`

### 4) ログイン

デフォルト認証情報（本番では変更してください）：

* ユーザー名: `admin`
* パスワード: `AdminPassword123!`

## データベース & マイグレーション

API は起動時に EF Core のマイグレーションを適用し、Spots / Events / OcDays のサンプルデータをシードします。

手動でマイグレーションを適用する場合：

```bash
cd apps/admin-api
# dotnet ef database update
```

## OpenAPI 運用ポリシー

Admin API の OpenAPI 仕様は `/packages/openapi/admin.yaml` に保存されており、これが **正（source of truth）** です。

Swagger から YAML をエクスポートするには：

```bash
dotnet tool install --global Swashbuckle.AspNetCore.Cli
swagger tofile --yaml ./apps/admin-api/bin/Debug/net8.0/AdminApi.dll v1 > ./packages/openapi/admin.yaml
```

## API 機能（MVP）

* 管理者ログイン（JWT）
* Spots / Events / OcDays の CRUD
* 公開状態のトグル
* スポット URL 向け QR コード PNG 生成
* 最近のログ一覧（直近 100 件）

## 今後のメモ

* 3D/AR 用に Spot フィールドを確保（コンテンツアセット、モデル参照など）。
* ログ集約と分析は後回し。
