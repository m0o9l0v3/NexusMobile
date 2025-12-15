# Nexus PWA (Smartphone-first)
QR/コード + GPS でスポット/イベントを提示する軽量 PWA。ANA のやさしい空色と FocusFlight のシックさをテーマに、フレームワークレス（Vanilla + Vite + TS）で実装しています。

## クイックスタート
- 前提: Node.js 20+
- 開発サーバ: `cd web && npm install && npm run dev`
- 本番ビルド: `cd web && npm run build`
- 環境変数: `.env.example` をコピーして `.env` を作成
  - `VITE_API_BASE_URL` … 実 API のエンドポイント
  - `VITE_USE_MOCK` … `true` ならフロント組み込みモックを利用
- Docker (任意): `docker-compose up --build` で Vite dev + json-server モックが立ち上がります（web:4173, mockapi:8787）。

## 画面フロー
- **Home `/`**
  - コード入力 / QR スキャン / 現在地ボタン
  - 本日のスケジュール（TicketCard 演出）と今日のイベント一覧
  - `/?code=XXXX` でスポットモーダルを直接表示（運営用 QR リンク想定）
- **Spot `/?code=XXXX`**
  - スポット詳細モーダル。関連リンクとタグ、代替導線のメッセージを表示
- **Nearby `/nearby`**
  - GPS 取得 → 距離順リスト + 精度バッジ。拒否時は手入力/ホーム導線
- **Events `/events`**
  - 今日のイベントシンプル一覧（Home のデータ流用）

## デザイン方針
- **ANA Light**: `--bg: #EAF4FF` の空色グラデ + 白カード。柔らかい影とラウンド角。
- **FocusFlight Dark**: ダーク背景 + ガラスカード。チケット/ゲートを思わせる演出。
- **テーマ切替**: `prefers-color-scheme` を初期値に、ヘッダーのトグルで light/dark を強制選択。
- **モーション**: `prefers-reduced-motion` を尊重。Ticket の切り込み演出は軽量 CSS のみ。
- **タイポ**: Noto Sans JP + Inter、数字は `tabular-nums`。

### コンポーネント一覧（/web/src/components）
- `AppShell` ヘッダー/ナビ + テーマトグル
- `Card` 汎用カード
- `Button` primary/secondary/ghost
- `Badge` ステータス/通知
- `Modal` スポット表示用
- `Toast` 成功/失敗フィードバック
- `TicketCard` 搭乗券風カード（コード・ミシン目・バーコード風）

### スタイルトークン
- `web/src/styles/design-tokens.css` … light/dark の CSS Variables
- `web/src/styles/base.css` … reset + layout + skeleton

## API ファースト
- OpenAPI: `openapi/public.yaml` を唯一の仕様として利用
- エンドポイント
  - `GET /api/spots/by-code/{code}`
  - `GET /api/events/today`
  - `GET /api/nearby?lat=&lng=&radius_m=`
  - `POST /api/logs`（匿名セッション、バッチ送信）
- モック: `VITE_USE_MOCK=true` でフロント内蔵モック。Docker の json-server でも `/api/*` を返します。

## PWA
- `public/manifest.webmanifest`
- `public/sw.js` … 静的キャッシュ + オフラインフォールバック
- `index.html` … モバイル向け meta + standalone 設定

## ログとプライバシー
- 匿名 `sessionId` を localStorage で生成・保持
- `logEvent` がローカルキューに積み、オンライン/visibilitychange でバッチ送信（失敗時リトライ）。
- 位置情報は精度（accuracy）を添えて送る想定。個人特定情報は扱わない。

## ディレクトリ
- `/web` … PWA（Vite + TypeScript + Vanilla）
- `/openapi/public.yaml` … API 仕様
- `/docs/overview.md` … 画面仕様・運用メモ
- `/mock-api` … json-server 用モックデータ・ルーティング

## TODO（次ステップ案）
- QR スキャナの UI 強化（連続読み取り/履歴）
- Lighthouse スコア検証と画像最適化パイプライン
- アクセシビリティ向上（フォーカスインジケーター、スクリーンリーダーチューニング）
- 位置情報の粗度設定 UI と同意ダイアログの実装
- E2E テスト（Playwright）追加
