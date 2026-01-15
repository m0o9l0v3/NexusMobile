## Nexus PWA 画面メモ

- **Home `/`**
  - ヒーローパネル（ログイン不要の案内 + CTAピルボタン）
  - おすすめカード横スクロール、クイックアクション丸ボタン
  - 今日のイベント一覧（モック） / `/?code=XXXX` でスポットモーダル
- **Nearby `/nearby`**
  - Geolocation 取得→距離順リスト、精度バッジ
  - 拒否時は手入力案内
- **Events `/events`**
  - `GET /api/events/today` モック一覧
- **Reserve `/reserve`**
  - Segmented + Input の予約フォーム風
- **Status `/status`**
  - 運航状況風リスト
- **Empty `/empty`**
  - EmptyStateの雛形

## API / モック運用
- `.env` の `VITE_USE_MOCK=true` でフロント内蔵モックデータを利用
- 実APIに接続する場合は `VITE_API_BASE_URL` を設定
- `VITE_RUNTIME=web|native` でランタイムを切替。`native` 時は Capacitor Geolocation を利用し、Service Worker は登録しない
- OpenAPI: `openapi/public.yaml`

## ログ / プライバシー
- 匿名 `sessionId` を localStorage に保持
- `POST /api/logs` にバッチ送信、失敗時はローカル再キュー
- 位置情報は精度付きの想定（個人特定しない粒度）

## PWA 運用
- `public/manifest.webmanifest` と `public/sw.js`
- 静的キャッシュ + オフラインフォールバック（HTML/manifest）
- HTTPS + service worker 有効化でインストール可能
