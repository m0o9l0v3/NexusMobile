# Nexus PWA (ライトテーマ / Material 3 ライク)
参加者向けスマホWebアプリ（PWA）。ANA系の空色グラデに、Material 3 のエレベーション・ステートレイヤー・リップルを軽量実装で取り入れたフレームワークレス構成（Vite + TypeScript + Vanilla）。

## 起動方法
- 前提: Node.js 20+
- 開発: `cd web && npm install && npm run dev`（PowerShellの実行ポリシーで躓く場合は `cmd /c "cd web && npm install"`）
- ビルド/プレビュー: `cd web && npm run build && npm run preview`
- 環境変数: `.env.example` を `.env` にコピーし、`VITE_API_BASE_URL` や `VITE_USE_MOCK` を設定
- Docker（任意）: `docker-compose up --build`（web:4173 / mockapi:8787）

## デザイン方針
- ライトテーマのみ。淡い空色グラデの背景、白カード＋大きめ角丸＋弱い影。
- Material 3 風: Elevation（`--elev-1/2/3`）、State layer（hover/pressed）、Ripple（transform/opacityのみ）。
- フォント: Noto Sans JP + Inter（数字は `tabular-nums`）。
- モーション: `prefers-reduced-motion` 時は transform/animation を停止し、色変化のみで状態を表現。
- BottomNavアニメ: アクティブで上に6px＋scale 1.1＋色変化＋淡いピル背景、200ms cubic-bezier(0.2,0,0,1)。reduce時はtransform無効。

## コンポーネント（/web/src/components）
- ベース: `AppShell`, `BottomNav`, `Card`, `Button`, `Badge`, `Modal`, `Toast`, `TicketCard`
- Material準拠: `SegmentedControl`, `Tabs`, `ListItem`, `InputField`, `EmptyState`, `Ripple`
- スタイル: `styles/design-tokens.css`, `styles/base.css`

## 画面
- Home `/`: ヒーロー（ログイン不要CTA）、おすすめ横スクロール、クイックアクション、イベント一覧（モック）
- Spot `/?code=XXXX`: スポット詳細モーダル（モック）
- Nearby `/nearby`: 位置情報取得→距離順リスト＋精度バッジ、拒否時メッセージ
- Events `/events`: 今日のイベント一覧（モック）
- Reserve `/reserve`: 予約フォーム風（Segmented + Input）
- Status `/status`: 運航状況風リスト
- Empty `/empty`: EmptyState雛形

## モバイル（Capacitor）
- 設定: `web/capacitor.config.ts`（appId/appName/webDir=dist）
- 追加: `npx cap add android` / `npx cap add ios`
- 同期: `npm run cap:sync`（内部でビルド→`npx cap sync`）
- IDE起動: `npm run cap:open:android` / `npm run cap:open:ios`
- Live Reload: `npx cap run android --external` 等（ファイアウォールでローカルIP許可が必要）
- 開発時の dev server 直結: `.env` に `VITE_RUNTIME=native` と `CAP_DEV_SERVER_URL=http://<PCのIP>:5173` を設定し、`npm run dev -- --host 0.0.0.0 --port 5173` を起動してから `npm run cap:run:android` などで接続

## 素材の置き場所とルール
- UI Kit: `/web/src/assets/ui-kit/icons/`, `/web/src/assets/ui-kit/illustrations/` を優先使用（リポジトリ内のみ）。不足時は自作SVGで補完。
- 外部ダウンロード禁止、既存サービスのロゴ/画像/文言の転用禁止。
- 差し替えは同名ファイルを置き換えればViteで自動反映。

## API / モック
- OpenAPI: `openapi/public.yaml`
- エンドポイント: `GET /api/spots/by-code/{code}`, `GET /api/events/today`, `GET /api/nearby`, `POST /api/logs`
- `VITE_USE_MOCK=true` でフロント内蔵モックを利用。`mock-api` + docker-compose でも同パスで応答。

## ランタイムとSW
- `VITE_RUNTIME=web|native` で切替。`native` の場合は Service Worker を登録せず、位置情報は Capacitor Geolocation を利用。
- PWA配布時は `VITE_RUNTIME=web` でビルドし、SW/manifest を有効にする。

## ログ/プライバシー
- 匿名 `sessionId` を localStorage に生成・保持。
- `logEvent` がキューに積み、オンライン/visibilitychange でバッチ送信（失敗時は再キュー）。
- 個人特定情報は扱わず、位置情報は精度付きの想定。

## TODO
- QRスキャンUX強化（連続読み取り・履歴・ガイド）
- Lighthouse/A11y改善（画像最適化、コントラスト、フォーカス表示）
- 位置情報の同意UIと粗度設定
- PlaywrightなどでE2Eテスト追加
