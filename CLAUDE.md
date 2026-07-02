# CLAUDE.md

このファイルは Claude Code が Nexus リポジトリで作業する際に毎セッション自動的に読み込む前提知識です。ここに書かれていることは常に守ってください。

## プロジェクト概要

Nexus は、オープンキャンパス向けの総合支援プラットフォーム（参加者向け PWA・iOS ネイティブアプリ・管理ポータル + 2 本の .NET API）。専門学校の卒業研究として約 3.5 年スパンで開発しており、将来的には「Nexus AI Ecosystem」（エージェント型コパイロット基盤）への発展を見据えている（`docs/nexus-ai-ecosystem.md` 参照）。

- 開発体制: 技術的意思決定者は 1 名（このリポジトリのオーナー）。他 2 名は Figma デザイン担当 1 名、学習中メンバー 1〜2 名。技術ロールの移譲経路がないため、変更は極力レビューしやすく・後から追いやすい形にすること。
- 卒業目標: 2029 年卒、高度専門士取得。

## リポジトリ構成

```
Nexus/
├── web/                # 参加者向け PWA（React 18 + Vite + Tailwind v4）
├── apps/
│   ├── admin-web/       # 管理ポータル（React 18 + Vite + Tailwind v4 + MUI v5 + TanStack Query）
│   ├── admin-api/        # 管理API（ASP.NET Core 8, JWT認証・書き込み）
│   ├── admin-api-tests/  # 管理APIユニットテスト
│   ├── public-api/       # 公開API（ASP.NET Core 8, 認証なし・読み取り専用）
│   ├── public-api.Tests/
│   ├── mobile-ios/       # iOSアプリ（Expo SDK 54 + React Native 0.81 + expo-router v6）
│   └── sensor-lab-ios/   # Phase 0 センサー検証アプリ（Swift/SwiftUI, 気圧センサーで屋内階層移動検知の実機検証）
├── packages/
│   ├── shared/           # 共通型・APIクライアント（@nexus/shared）
│   └── openapi/          # Admin API OpenAPI定義（admin.yaml, source of truth）
├── openapi/public.yaml   # Public API OpenAPI定義
├── docs/                 # 設計・フェーズドキュメント
├── mock-api/             # json-server モック
└── docker-compose.yml
```

## 技術スタック早見表

| Area | Stack |
|---|---|
| 参加者向け PWA | React 18 + Vite + Tailwind CSS v4、ハッシュルーター |
| 管理ポータル | React 18 + Vite + Tailwind v4 + MUI v5 + TanStack Query |
| 管理API | ASP.NET Core 8, EF Core（SQLite/PostgreSQL切替）, Serilog |
| 公開API | ASP.NET Core 8, Admin DBを読み取り専用でProjectReference共有 |
| iOS | Expo SDK 54 + React Native 0.81 + expo-router v6 |
| Sensor Lab | Swift / SwiftUI（`CMAltimeter`） |

**重要な方針転換の注意**: mobile-ios は現状 Expo/React Native で実装されているが、今後 SwiftUI（iOS）+ Kotlin Multiplatform（共有ロジック）+ Jetpack Compose（Android）の「UIはネイティブ、頭脳は共有」構成への移行を検討中。この移行は**まだコードには反映されていない**。移行作業を依頼された場合は、既存の Expo 実装との併存期間や移行手順について必ず方針を確認してから着手すること。

## 開発コマンド

```bash
# 参加者向け PWA
cd web && npm install && npm run dev        # http://localhost:5176
npm run typecheck                            # tsc --noEmit

# 管理ポータル
cd apps/admin-web && npm install && npm run dev
npm run generate:api                         # OpenAPIから型再生成
npm run typecheck

# 管理API
cd apps/admin-api && dotnet run              # http://localhost:5000 (SQLite dev)
dotnet test ../admin-api-tests               # ※後述のOneDrive注意点あり

# 公開API
cd apps/public-api && dotnet run             # http://localhost:5001

# iOSアプリ
cd apps/mobile-ios && npm install && npm run start
npm run ios          # シミュレーター起動（macOS + Xcode必須）
npm run typecheck
npm run lint          # expo lint

# 全体
docker-compose up --build   # admin-api(5000) / public-api(5001) / postgres(5432)
```

- `web/` は `VITE_USE_MOCK=true` でAPI無しにフロント内蔵モックのみで動く。
- admin-web の Admin API型は `openapi-typescript` で自動生成（手で編集しない、`generate:api` を再実行する）。
- Windows/OneDrive 環境で `admin-api-tests` を実行する場合は `C:\Work\Nexus` にコピーしてから実行する必要がある（README記載の既知の制約）。
- Expo Go 接続に失敗する場合は `--lan` / `--tunnel` を試す。WSL/Docker上でMetroを動かしている場合は `--tunnel` かホストOS側起動が必要（README「Expo Go接続トラブル」参照）。

## アーキテクチャ上の重要な設計判断

- **admin-api / public-api の分離**: 書き込み・JWT認証系は admin-api、読み取り専用・認証なしは public-api に明確に分離している。新しい書き込みエンドポイントを public-api に追加しない。public-api は admin-api の DB を ProjectReference 経由で読み取り専用共有している。
- **JWT失効管理**: 発行時に `jti` を記録し、失効対象は `revoked_jti` テーブルで管理。認証ミドルウェアが全リクエストで失効チェックを行う。トークン関連の変更をする際はこの仕組みを壊さないこと。
- **QRワンタイムコード**: HMACでハッシュ化してDB保存（平文保存禁止）。引換後は即失効、イベント当日23:59:59 JSTで期限切れ。
- **監査ログのハッシュチェーン**: 各ログに `prev_hash`（前レコードのHMAC-SHA256）を連鎖させて改ざん検知を可能にしている。ログ関連のスキーマ変更をする際はチェーンの整合性を壊さないよう注意。
- **将来 `Nexus.Domain / Application / Infrastructure / Contracts` へのレイヤードアーキテクチャへのリファクタリングを予定**（未着手）。大きな構造変更を提案する場合はこの方向性と整合させる。
- **AIサポート機能（`web/src/ai/support/`）は現状LLMを使わない設計**。バージョン管理されたナレッジパック（`exhibits.v1.json` / `troubles.v1.json`）とテンプレート応答のみで完結させている（`docs/nexus-ai-ecosystem.md` の "Template-first, rule-first" 方針）。ここに安易にLLM呼び出しを追加しない。

## デザインルール（`docs/design-rules.md` 要約）

- 余白: コンテンツ間16px、セクション20px、タップ領域44px以上
- 角丸: 通常16px、主要カード20px、ヒーロー/ボトムナビ外枠22-28px
- Material 3風 Elevation（`--elev-1/2/3`）、State layer、Ripple
- フォント: Noto Sans JP + Inter、数字は `tabular-nums`
- ライトテーマ固定、淡い空色グラデ背景 + 白カード + 弱い影
- `prefers-reduced-motion: reduce` では transform/animation を止め、色変化のみで状態表現
- UIは「1画面1主目的」。常時表示CTAはHome未チェックイン時のみ、他は控えめに

新しいUIを実装・提案する際はこのルールに沿わせること。詳細は `web/DESIGN_SYSTEM.md` / `web/IMPLEMENTATION_GUIDE.md` も参照。

## セキュリティ上、絶対に守ること

- `apps/admin-api` のデフォルト管理者パスワード（`AdminPassword123!`）はローカル開発専用のシード値。本番設定や実際の秘密情報として絶対に使わない・コミットしない。
- `appsettings.json` の `CHANGE_ME_TO_A_LONG_RANDOM_SECRET` のようなプレースホルダーは、本番デプロイ手順の提案時に必ず差し替えを促すこと。
- QRコード・トークン・個人情報（氏名・年齢・高校名など）をログや平文で保存するコードを書かない。
- 参加者ログの位置情報は「個人特定しない粒度」を保つ設計方針（`docs/overview.md`）。精度を上げすぎる変更は提案しない。

## ドキュメント参照先

| ファイル | 内容 |
|---|---|
| `docs/nexus-ai-ecosystem.md` | AIエコシステム全体方針・フェーズロードマップ |
| `docs/design-rules.md` | UIデザインルール |
| `docs/overview.md` | PWA画面メモ・API運用方針 |
| `docs/security.md` | セキュリティ設計メモ（QR/JWT/監査ログ） |
| `docs/phase0/validation-plan.md` | Sensor Lab技術検証計画 |
| `docs/phase1/route-ui-event-contract.md` | ルート表示UIイベント契約 |
| `docs/expo-sdk-54-migration.md` | Expo SDK 51→54移行メモ |
| `web/DESIGN_SYSTEM.md` / `web/IMPLEMENTATION_GUIDE.md` | フロントエンド詳細 |

## 今後の計画（TODO抜粋、詳細はREADME参照）

- Phase 1: ルート表示UI強化（ステップ案内・フロア跨ぎ・逸脱検知）、管理コンソールへのオペレーターハンドオフ
- Sensor Labの屋内階層移動検知ロジックをmobile-iosへ移植
- E2Eテスト（Playwright想定）・Lighthouse/A11y改善
- ログ集約・分析ダッシュボード

## 作業時の基本姿勢

- 変更は小さく、レビューしやすい単位に分割する（チーム内でレビューできるのが実質1名のため）。
- 新しいライブラリやアーキテクチャパターンを導入する提案をする際は、必ず理由と代替案を添える（判断の移譲先がないため、記録が特に重要）。
- README・docs配下と実装が食い違っている場合は、黙って合わせるのではなく食い違いを指摘すること。