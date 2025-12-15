## Nexus PWA 画面メモ

- **Home `/`**
  - QR/コード入力、QRスキャン、現在地誘導ボタン
  - 今日のイベント一覧と TicketCard による「本日のスケジュール」表示
  - `/?code=XXXX` でモーダル表示
- **Nearby `/nearby`**
  - Geolocation 取得 → 距離順リスト表示、精度バッジ
  - 拒否時はエラーメッセージ＋手入力推奨
- **Events `/events`**
  - `GET /api/events/today` の一覧。Home と同じデータをシンプルに列挙

## API / モック運用

- `.env` の `VITE_USE_MOCK=true` でフロント内蔵のモックデータを利用
- 実 API へ接続する場合は `VITE_API_BASE_URL` を設定し、ネットワーク許可を与える
- OpenAPI: `openapi/public.yaml`

## ログ / プライバシー

- 匿名 `sessionId` を localStorage に保存
- `POST /api/logs` へバッチ送信、失敗時は localStorage に再キューイング
- 位置情報は精度とともに送る想定（個人特定しない粒度で）

## PWA 運用

- `public/manifest.webmanifest` と `public/sw.js`
- 静的キャッシュ（HTML/manifest）＋ネットワークフォールバック
- HTTPS + `serviceWorker` 有効化でアイコン/インストール可能
