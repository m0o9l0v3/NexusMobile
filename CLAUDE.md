# CLAUDE.md

このファイルは Claude Code が Nexus リポジトリで作業する際に毎セッション自動的に読み込む前提知識です。ここに書かれていることは常に守ってください。

## プロジェクト概要

Nexus は、オープンキャンパス向けの総合支援プラットフォーム（参加者向け iOS アプリ・イベント告知 Web LP・管理ポータル + 2 本の .NET API）。管理ポータルは別プロダクト **Nexus Studio**（[nexusstudio](https://gitlab.com/11h27m/nexusstudio) リポジトリ）が担当する（[E0-7](docs/decisions/E0-7-studio-scope-split.md)）。専門学校の卒業研究として約 3.5 年スパンで開発しており、将来的には「Nexus AI Ecosystem」（エージェント型コパイロット基盤）への発展を見据えている（`docs/nexus-ai-ecosystem.md` 参照）。

v1.0 の包含・除外とリリース条件は [`docs/v1.0-scope.md`](docs/v1.0-scope.md) を正とする。参加者向けアプリ機能は iOS に限定し、`web/` はイベント告知・当日案内・iOS アプリへの導線を担う LP へ再構成する。この決定経緯は [Work item #7](https://gitlab.com/11h27m/nexus-mobile/-/work_items/7)、LP の実装・公開ルート・API 利用範囲・QR 挙動は [Work item #81](https://gitlab.com/11h27m/nexus-mobile/-/work_items/81) を参照する。

- 開発体制: 技術的意思決定者は 1 名（このリポジトリのオーナー）。他 2 名は Figma デザイン担当 1 名、学習中メンバー 1〜2 名。技術ロールの移譲経路がないため、変更は極力レビューしやすく・後から追いやすい形にすること。
- 卒業目標: 2029 年卒、高度専門士取得。

## リポジトリ構成

```
Nexus/
├── web/                # イベント告知 LP（React 18 + Vite + Tailwind v4、#81 で再構成）
├── apps/
│   ├── admin-web/       # 【排除対象】管理ポータル（E0-7 により Nexus Studio へ移管）
│   ├── admin-api/        # 管理API（ASP.NET Core 8, JWT認証・書き込み）
│   ├── admin-api-tests/  # 管理APIユニットテスト
│   ├── public-api/       # 公開API（ASP.NET Core 8, 認証なし・読み取り専用）
│   ├── public-api.Tests/
│   ├── nexus-ios/        # 【正本】参加者向けiOSアプリ（SwiftUI / Swift、E0-6）
│   ├── mobile-ios/       # 【撤去対象】旧iOSアプリ（Expo SDK 54 + React Native 0.81）
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
| イベント告知 LP | React 18 + Vite + Tailwind CSS v4（#81 実施前は旧 PWA プロトタイプ） |
| 管理ポータル | **Nexus Studio**（別リポジトリ）。`apps/admin-web` は排除対象 |
| 管理API | ASP.NET Core 8, EF Core（SQLite/PostgreSQL切替）, Serilog |
| 公開API | ASP.NET Core 8, Admin DBを読み取り専用でProjectReference共有 |
| iOS（正本） | SwiftUI / Swift（`apps/nexus-ios`） |
| iOS（撤去対象） | Expo SDK 54 + React Native 0.81 + expo-router v6（`apps/mobile-ios`） |
| Sensor Lab | Swift / SwiftUI（`CMAltimeter`） |

**重要（2026-09-22 更新）**: SwiftUI への移行は**決定済みで、実装も進行中**。参加者向け iOS の正本は `apps/nexus-ios` であり（[E0-6](docs/decisions/E0-6-ios-client-of-record.md)）、タブは ホーム / マップ / 案内 / 探す の4タブ（[E6-1](docs/decisions/E6-1-tab-structure.md)）。`apps/mobile-ios` は撤去対象で、機能追加をしない。

ただし `apps/nexus-ios` で完成しているのは **4タブの UI と注入境界だけ**である。`import MapKit` / `import CoreLocation` / `URLSession` / 永続化 API の出現はいずれも 0 件で、地図・位置情報・データ取得・経路は未接続（E3〜E5 はほとんど未実装）。**コードが存在することを実装完了の根拠にしない。**

Kotlin Multiplatform（共有ロジック）+ Jetpack Compose（Android）への展開は未決定で、v1.0 の対象外。

## 開発コマンド

```bash
# イベント告知 LP
cd web && npm install && npm run dev        # http://localhost:5176
npm run typecheck                            # tsc --noEmit

# 管理ポータル（排除対象。新規作業は Nexus Studio 側で行う）
cd apps/admin-web && npm install && npm run dev
npm run generate:api                         # OpenAPIから型再生成
npm run typecheck

# 管理API
cd apps/admin-api && dotnet run              # http://localhost:5000 (SQLite dev)
dotnet test ../admin-api-tests               # ※後述のOneDrive注意点あり

# 公開API
cd apps/public-api && dotnet run             # http://localhost:5001

# iOSアプリ（正本: SwiftUI）
open apps/nexus-ios/Nexus.xcodeproj          # macOS + Xcode必須
# ※ Nexus.sln にも CI にも未登録のため、自動検証は現状ない

# iOSアプリ（撤去対象: Expo）
cd apps/mobile-ios && npm install && npm run start
npm run ios          # シミュレーター起動（macOS + Xcode必須）
npm run typecheck
npm run lint          # expo lint

# 全体
docker-compose up --build   # admin-api(5000) / public-api(5001) / postgres(5432)
```

- `web/` の現行コードが参照する環境変数は `VITE_API_BASE_URL` のみ。`VITE_USE_MOCK`、`VITE_RUNTIME`、`CAP_DEV_SERVER_URL` は実装されていない。
- admin-web の Admin API型は `openapi-typescript` で自動生成（手で編集しない、`generate:api` を再実行する）。
- Windows/OneDrive 環境で `admin-api-tests` を実行する場合は `C:\Work\Nexus` にコピーしてから実行する必要がある（README記載の既知の制約）。
- Expo Go 接続に失敗する場合は `--lan` / `--tunnel` を試す。WSL/Docker上でMetroを動かしている場合は `--tunnel` かホストOS側起動が必要（README「Expo Go接続トラブル」参照）。

## アーキテクチャ上の重要な設計判断

- **admin-api / public-api の分離**: 書き込み・JWT認証系は admin-api、読み取り専用・認証なしは public-api に明確に分離している。新しい書き込みエンドポイントを public-api に追加しない。public-api は admin-api の DB を ProjectReference 経由で読み取り専用共有している。
- **JWT失効管理**: 発行時に `jti` を記録し、失効対象は `revoked_jti` テーブルで管理。認証ミドルウェアが全リクエストで失効チェックを行う。トークン関連の変更をする際はこの仕組みを壊さないこと。
- **QRワンタイムコード**: hidden beta としてコードを保全し、v1.0 の正式機能や主要導線には含めない。HMACでハッシュ化してDB保存（平文保存禁止）。引換後は即失効、イベント当日23:59:59 JSTで期限切れ。
- **監査ログのハッシュチェーン**: 各ログに `prev_hash`（前レコードのHMAC-SHA256）を連鎖させて改ざん検知を可能にしている。ログ関連のスキーマ変更をする際はチェーンの整合性を壊さないよう注意。
- **将来 `Nexus.Domain / Application / Infrastructure / Contracts` へのレイヤードアーキテクチャへのリファクタリングを予定**（未着手）。大きな構造変更を提案する場合はこの方向性と整合させる。
- **AIサポート機能（`web/src/ai/support/`）は旧 PWA プロトタイプの資産**。現状はLLMを使わず、バージョン管理されたナレッジパック（`exhibits.v1.json` / `troubles.v1.json`）とテンプレート応答のみで完結している。LP に再利用する範囲は #81 で判断し、独自に公開機能へ組み込まない。再利用する場合も `docs/nexus-ai-ecosystem.md` の "Template-first, rule-first" 方針を維持し、安易にLLM呼び出しを追加しない。

## デザインルール（`docs/design-rules.md` 要約）

- 余白: コンテンツ間16px、セクション20px、タップ領域44px以上
- 角丸: 通常16px、主要カード20px、ヒーロー/ボトムナビ外枠22-28px
- Material 3風 Elevation（`--elev-1/2/3`）、State layer、Ripple
- フォント: Noto Sans JP + Inter、数字は `tabular-nums`
- ライトテーマ固定、淡い空色グラデ背景 + 白カード + 弱い影
- `prefers-reduced-motion: reduce` では transform/animation を止め、色変化のみで状態表現
- UIは「1画面1主目的」。LP で採用する画面・CTAは #81 の情報設計に従う

新しいUIを実装・提案する際はこのルールに沿わせること。`web/DESIGN_SYSTEM.md` / `web/IMPLEMENTATION_GUIDE.md` は旧 PWA のデザイン資産として参照できるが、LP への採用範囲は #81 に従う。

## セキュリティ上、絶対に守ること

- `apps/admin-api` のデフォルト管理者パスワード（`AdminPassword123!`）はローカル開発専用のシード値。本番設定や実際の秘密情報として絶対に使わない・コミットしない。
- `appsettings.json` の `CHANGE_ME_TO_A_LONG_RANDOM_SECRET` のようなプレースホルダーは、本番デプロイ手順の提案時に必ず差し替えを促すこと。
- QRコード・トークン・個人情報（氏名・年齢・高校名など）をログや平文で保存するコードを書かない。
- 参加者ログの位置情報は「個人特定しない粒度」を保つ設計方針（`docs/overview.md`）。精度を上げすぎる変更は提案しない。

## ドキュメント参照先

| ファイル | 内容 |
|---|---|
| `docs/v1.0-scope.md` | v1.0の製品境界・必須成果・対象外・リリース条件の正本 |
| `docs/decisions/` | 技術・データ契約の決定記録（E0-5〜E0-7、E1-1〜E1-5、E6-1） |
| `docs/ios-native-migration-plan.md` | SwiftUIネイティブ移行計画（承認済み） |
| `docs/nexus-ai-ecosystem.md` | AIエコシステム全体方針・フェーズロードマップ |
| `docs/design-rules.md` | UIデザインルール |
| `docs/overview.md` | Web LP方針・移行状況・API利用境界 |
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
- `web/` を参加者向けアプリとして拡張したり、iOS と機能同期したりしない。LP の実装判断は #81 の範囲に従う。
- README・docs配下と実装が食い違っている場合は、黙って合わせるのではなく食い違いを指摘すること。
