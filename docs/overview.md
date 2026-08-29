## Nexus PWA 画面メモ

> **文書ステータス（2026-08-30）:** この文書は、v1.0 の正式提供外として凍結された `web/` PWA の旧設計メモです。v1.0 の参加者向けクライアントは iOS アプリに限定されます。以下の内容を現行仕様やリリース対象として扱わず、凍結コードを参照・保守する場合にのみ使用してください。

- **Check-in `/checkin?token=XXXX`**
  - 公式QRコード（スマホ内蔵スキャナ）からアクセス
  - 基本情報フォーム（氏名・年齢・高校名・学科）を入力して送信
  - 完了後 `/app` に遷移し、以降はチェックインUIを表示しない
- **Home `/app`**
  - ヒーローパネル（スポットコード入力の案内）
  - おすすめカード横スクロール、クイックアクション丸ボタン
  - 今日のイベント一覧（モック） / `/app?code=XXXX` でスポットモーダル
- **Nearby `/app/nearby`**
  - Geolocation 取得→距離順リスト、精度バッジ
  - 拒否時は手入力案内
- **Events `/app/events`**
  - `GET /api/events/today` モック一覧
- **Reserve `/app/reserve`**
  - Segmented + Input の予約フォーム風
- **Status `/app/status`**
  - 運航状況風リスト
- **Empty `/app/empty`**
  - EmptyStateの雛形

## API / モック運用
- `.env` の `VITE_USE_MOCK=true` でフロント内蔵モックデータを利用
- 実APIに接続する場合は `VITE_API_BASE_URL` を設定
- `VITE_RUNTIME=web|native` でランタイムを切替。`native` 時は Capacitor Geolocation を利用し、Service Worker は登録しない
- OpenAPI: `openapi/public.yaml`

## チェックイン / ローカル保持
- ログインはスマホ内蔵QRスキャナ → `/checkin?token=XXXX` に誘導
- チェックイン完了後は `localStorage` の `nexus.profile.v1` にフラグ + プロフィールを保存
- テスト時は `/app` 画面の「チェックインをリセット」ボタンで削除

## ログ / プライバシー
- 匿名 `sessionId` を localStorage に保持
- `POST /api/logs` にバッチ送信、失敗時はローカル再キュー
- 位置情報は精度付きの想定（個人特定しない粒度）

## PWA 運用
- `public/manifest.webmanifest` と `public/sw.js`
- 静的キャッシュ + オフラインフォールバック（HTML/manifest）
- HTTPS + service worker 有効化でインストール可能
