# Nexus

## Overview
Nexus は、参加者向けスマホ Web アプリ（PWA）と管理ポータル、公開 API / 管理 API で構成されるプロジェクトです。参加者向け UI は ANA 系の空色グラデに、Material 3 のエレベーション・ステートレイヤー・リップルを軽量実装で取り入れたフレームワークレス構成（Vite + TypeScript + Vanilla）です。

## Apps

### Participant PWA
- 想定ディレクトリ: `web`
- 主な画面:
  - Home `/`: ヒーロー（ログイン不要 CTA）、おすすめ横スクロール、クイックアクション、イベント一覧（モック）
  - Spot `/?code=XXXX`: スポット詳細モーダル（モック）
  - Nearby `/nearby`: 位置情報取得→距離順リスト＋精度バッジ、拒否時メッセージ
  - Events `/events`: 今日のイベント一覧（モック）
  - Reserve `/reserve`: 予約フォーム風（Segmented + Input）
  - Status `/status`: 運航状況風リスト
  - Empty `/empty`: EmptyState 雛形
- コンポーネント（`/web/src/components`）:
  - ベース: `AppShell`, `BottomNav`, `Card`, `Button`, `Badge`, `Modal`, `Toast`, `TicketCard`
  - Material 準拠: `SegmentedControl`, `Tabs`, `ListItem`, `InputField`, `EmptyState`, `Ripple`
  - スタイル: `styles/design-tokens.css`, `styles/base.css`
- デザイン方針:
  - ライトテーマのみ。淡い空色グラデ背景、白カード＋大きめ角丸＋弱い影
  - Material 3 風: Elevation（`--elev-1/2/3`）、State layer（hover/pressed）、Ripple（transform/opacity のみ）
  - フォント: Noto Sans JP + Inter（数字は `tabular-nums`）
  - モーション: `prefers-reduced-motion` 時は transform/animation を停止し、色変化のみで状態を表現
  - BottomNav アニメ: アクティブで上に 6px + scale 1.1 + 色変化 + 淡いピル背景、200ms cubic-bezier(0.2,0,0,1)。reduce 時は transform 無効
  - テーマ固定: UX 一貫性のためライトテーマ固定（自動ダーク化やユーザー切替なし）
- ランタイム:
  - `VITE_RUNTIME=web|native` で切替
  - `native` の場合は Service Worker 未登録、位置情報は Capacitor Geolocation を利用
  - PWA 配布時は `VITE_RUNTIME=web` でビルドし、SW/manifest を有効化
- モバイル（Capacitor）:
  - 設定: `web/capacitor.config.ts`（appId/appName/webDir=dist）
  - 追加: `npx cap add android` / `npx cap add ios`
  - 同期: `npm run cap:sync`（内部でビルド→`npx cap sync`）
  - IDE 起動: `npm run cap:open:android` / `npm run cap:open:ios`
  - Live Reload: `npx cap run android --external` 等（ローカル IP 許可が必要）
  - 開発時の dev server 直結: `.env` に `VITE_RUNTIME=native` と `CAP_DEV_SERVER_URL=http://<PCのIP>:5176` を設定し、`npm run dev -- --host 0.0.0.0 --port 5176` 後に `npm run cap:run:android` などで接続
- 素材ルール:
  - UI Kit: `/web/src/assets/ui-kit/icons/`, `/web/src/assets/ui-kit/illustrations/` を優先利用（リポジトリ内のみ）
  - 外部ダウンロード禁止、既存サービスのロゴ/画像/文言の転用禁止
  - 差し替えは同名ファイルの置換で Vite により自動反映
- ログ/プライバシー:
  - 匿名 `sessionId` を localStorage に生成・保持
  - `logEvent` がキューへ積み、online/visibilitychange でバッチ送信（失敗時は再キュー）
  - 個人特定情報は扱わず、位置情報は精度付きの想定

### Admin
- 想定ディレクトリ: `apps/admin-web`
- 開発サーバー: `http://localhost:5173`
- ログイン（デフォルト認証情報）:
  - ユーザー名: `admin`
  - パスワード: `AdminPassword123!`

### Public API
- 想定 OpenAPI: `openapi/public.yaml`
- エンドポイント:
  - `GET /api/spots/by-code/{code}`
  - `GET /api/events/today`
  - `GET /api/nearby`
  - `POST /api/logs`

### Admin API
- 開発時の利用先: `http://localhost:5000`
- Swagger UI（Development）: `http://localhost:5000/swagger`
- API 機能（MVP）:
  - 管理者ログイン（JWT）
  - Spots / Events / OcDays の CRUD
  - 公開状態のトグル
  - スポット URL 向け QR コード PNG 生成
  - 最近のログ一覧（直近 100 件）
- データベース / マイグレーション:
  - 起動時に EF Core マイグレーション適用、Spots / Events / OcDays のサンプルデータをシード
  - 手動適用例:
    ```bash
    cd apps/admin-api
    # dotnet ef database update
    ```

## Local Development

### Participant PWA
```bash
cd web
npm install
npm run dev
```

- 前提: Node.js 20+
- PowerShell の実行ポリシーで躓く場合: `cmd /c "cd web && npm install"`
- ビルド/プレビュー: `cd web && npm run build && npm run preview`
- モック利用: `VITE_USE_MOCK=true` でフロント内蔵モックを利用

### Admin API
API は `http://localhost:5000` で利用できます。Swagger UI は Development 環境で `http://localhost:5000/swagger` から参照できます。

### Admin Web
```bash
cd apps/admin-web
npm install
npm run dev
```

`http://localhost:5173` を開いてください。

## Environment Variables
`.env.example` を `.env` にコピーし、用途に応じて以下を設定してください。

- Participant PWA
  - `VITE_API_BASE_URL`
  - `VITE_USE_MOCK`
  - `VITE_RUNTIME`
  - `CAP_DEV_SERVER_URL`
- Admin Web
  - `VITE_ADMIN_API_BASE_URL`
  - `VITE_PARTICIPANT_BASE_URL`

## Docker Compose
- 任意で `docker-compose up --build` を利用可能
- 既存記載のポート: web `4173` / mockapi `8787`
- `mock-api` + docker-compose でも Public API と同一パスで応答

## OpenAPI
- Public API: `openapi/public.yaml`
- Admin API: `/packages/openapi/admin.yaml`（source of truth）

Swagger から YAML をエクスポートする例:

```bash
dotnet tool install --global Swashbuckle.AspNetCore.Cli
swagger tofile --yaml ./apps/admin-api/bin/Debug/net8.0/AdminApi.dll v1 > ./packages/openapi/admin.yaml
swagger tofile --yaml ./apps/public-api/bin/Debug/net8.0/PublicApi.dll v1 > ./openapi/public.yaml
```

## TODO
- QR スキャン UX 強化（連続読み取り・履歴・ガイド）
- Lighthouse/A11y 改善（画像最適化、コントラスト、フォーカス表示）
- 位置情報の同意 UI と粗度設定
- Playwright などで E2E テスト追加
- 3D/AR 用に Spot フィールドを確保（コンテンツアセット、モデル参照など）
- ログ集約と分析は後回し
