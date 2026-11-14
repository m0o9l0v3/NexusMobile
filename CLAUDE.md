# CLAUDE.md

このファイルは Claude Code が Nexus リポジトリで作業する際に毎セッション自動的に読み込む前提知識です。ここに書かれていることは常に守ってください。

## プロジェクト概要

Nexus は、オープンキャンパス向けの総合支援プラットフォーム（参加者向け iOS アプリ・公開サイト + .NET の公開 API。公開データの編集と公開は別リポジトリの NexusStudio が担う）。専門学校の卒業研究として約 3.5 年スパンで開発しており、将来的には「Nexus AI Ecosystem」（エージェント型コパイロット基盤）への発展を見据えている（`docs/nexus-ai-ecosystem.md` 参照）。

v1.0 の包含・除外とリリース条件は [`docs/v1.0-scope.md`](docs/v1.0-scope.md) を正とする。参加者向けアプリ機能は iOS に限定し、`web/` はアプリの告知・開発状況・サーバー状況・技術説明を掲載する公開サイトにする（2026-10-25 決定、v1.0 に含める）。iOS 限定の決定経緯は [Work item #7](https://github.com/m0o9l0v3/NexusMobile/issues/7)、公開サイトのページ構成・データ源・公開先・QR 挙動は [Work item #131](https://github.com/m0o9l0v3/NexusMobile/issues/131) を参照する。以前の「イベント告知 LP」（#81）は実装されないまま Close されており、#131 に置き換えた。管理ポータル（`apps/admin-web`）と admin-api は v1.0 の本番に置かず、公開データの編集と公開は NexusStudio が担う（2026-11-14 決定、[`docs/decisions/E8-7-production-cors-origins.md`](docs/decisions/E8-7-production-cors-origins.md) の C-4）。そのため E7 は v1.0 の必須成果に含めない。管理ポータル（旧 `apps/admin-web`）は 2026-11-14 に削除した。admin-api も、共有していた DB の型と移行を `apps/nexus-data`（`Nexus.Data`）へ移したうえで 2026-11-14 に削除した（[`docs/decisions/E8-7-r1-admin-api-removal.md`](docs/decisions/E8-7-r1-admin-api-removal.md)）。admin-api と hidden beta のコードは git 履歴（削除直前は `fb539f7`）から復元する。

- 開発体制: 技術的意思決定者は 1 名（このリポジトリのオーナー）。他 2 名は Figma デザイン担当 1 名、学習中メンバー 1〜2 名。技術ロールの移譲経路がないため、変更は極力レビューしやすく・後から追いやすい形にすること。
- 卒業目標: 2029 年卒、高度専門士取得。

## リポジトリ構成

```
Nexus/
├── web/                # 公開サイト（React 18 + Vite + Tailwind v4、#131。現在は準備中の1ページ）
├── apps/
│   ├── nexus-data/       # Nexus.Data：DB の形・移行・起動時の DB 検査・監査ログのチェーン（名前空間は AdminApi.* のまま）
│   ├── public-api/       # 公開API（ASP.NET Core 8, 認証なし・読み取り専用）
│   ├── public-api.Tests/
│   └── nexus-ios/        # 現行 iOS アプリ（Swift / SwiftUI）
├── packages/
│   └── shared/           # 共通型・APIクライアント（@nexus/shared）
├── openapi/public.yaml   # Public API OpenAPI定義
├── docs/                 # 設計・フェーズドキュメント
├── tools/database/       # 移行 SQL の出力・audit-verify・dev-init・使い捨て DB での検証
├── mock-api/             # json-server モック
└── docker-compose.yml
```

## 技術スタック早見表

| Area | Stack |
|---|---|
| 公開サイト | React 18 + Vite + Tailwind CSS v4（旧 PWA は 2026-10-25 に削除） |
| DB | EF Core 8（SQLite/PostgreSQL切替）。`apps/nexus-data`（Nexus.Data）に集約 |
| 公開API | ASP.NET Core 8, Serilog。Nexus.Data を ProjectReference で使い、書き込みは `visit_logs` の INSERT だけ |
| iOS | SwiftUI / Xcode（`apps/nexus-ios/`、Home / Map / 案内 / 探す） |

現行 iOS アプリは `apps/nexus-ios/` の SwiftUI プロジェクトです。旧Expo / React Native アプリ `apps/mobile-ios/` は2026-09-29に削除しました。

Phase 0 センサー検証アプリ `apps/sensor-lab-ios/` は試験段階の構想にとどまったため、2026-10-24にプロジェクトとして凍結し、関連文書（`docs/phase0/validation-plan.md`、`docs/mobile-sensor-integration-plan.md`）とともに削除しました。再開する場合は git 履歴（削除直前は `4de2e6a`）から復元します。

## 開発コマンド

```bash
# 公開サイト
cd web && npm install && npm run dev        # http://localhost:5176
npm run typecheck                            # tsc --noEmit

# 開発用DB（SQLite。PostgreSQL は README「Docker Compose」）
NEXUS_DEV_DATABASE=1 NEXUS_DEV_CONNECTION="Data Source=apps/public-api/admin-dev.db" \
  dotnet run --project tools/database/Nexus.Database.csproj -- dev-init

# 公開API
cd apps/public-api && dotnet run             # http://localhost:5001
dotnet test apps/public-api.Tests            # 公開API・Nexus.Data のテスト

# iOSアプリ（macOS + Xcode）
open apps/nexus-ios/Nexus.xcodeproj
# Scheme: Nexus。シミュレーター build/test は root README の手順を参照。

# 全体
docker-compose up --build   # public-api(5001) / postgres(5432)
```

- `web/` の現行コードは環境変数を参照しない（public-api を使うときに #131 で定める）。`VITE_USE_MOCK`、`VITE_RUNTIME`、`CAP_DEV_SERVER_URL` は実装されていない。

## アーキテクチャ上の重要な設計判断

- **public-api は読み取り専用**: 認証なし・読み取り専用で、書き込みは `visit_logs` の INSERT だけ。新しい書き込みエンドポイントを public-api に追加しない。公開データの書き込みは NexusStudio が担う。DB の型と移行は `apps/nexus-data`（Nexus.Data）にあり、public-api は ProjectReference で使う。admin-api（書き込み・JWT認証）は 2026-11-14 に削除した。
- **JWT失効管理**: JWT を発行する API は今は無い（admin-api とともに削除。`revoked_jti` などの表は移行履歴を変えないため残している）。JWT を発行する機能を復元・追加する場合は、発行時に `jti` を記録し、失効対象は `revoked_jti` テーブルで管理し、認証ミドルウェアが全リクエストで失効チェックを行う仕組みを必ず保つこと。
- **QRワンタイムコード**: hidden beta のコード（QR 発行・ワンタイムコード・`/q/{token}`）は admin-api とともに 2026-11-14 に削除し、git 履歴（削除直前は `fb539f7`）に保全している（E8-7 r1 D-4）。v1.0 の正式機能や主要導線には含めない。復元する場合も、HMACでハッシュ化してDB保存（平文保存禁止）、引換後は即失効、イベント当日23:59:59 JSTで期限切れ、を守る。
- **監査ログのハッシュチェーン**: 各ログに `prev_hash`（前レコードのHMAC-SHA256）を連鎖させて改ざん検知を可能にしている。本番で運用し、検証は `tools/database` の `audit-verify`（読み取り専用）で行う（`docs/security.md`）。ログ関連のスキーマ変更をする際はチェーンの整合性を壊さないよう注意。
- **将来 `Nexus.Domain / Application / Infrastructure / Contracts` へのレイヤードアーキテクチャへのリファクタリングを予定**（未着手）。大きな構造変更を提案する場合はこの方向性と整合させる。
- **旧 PWA の AIサポート機能（旧 `web/src/ai/support/`）は 2026-10-25 に削除した**（git 履歴に残る）。LLMを使わず、ナレッジパック（`exhibits.v1.json` / `troubles.v1.json`）とテンプレート応答だけで完結していた。復元・再利用する場合も `docs/nexus-ai-ecosystem.md` の "Template-first, rule-first" 方針を維持し、安易にLLM呼び出しを追加しない。

## デザインルール（`docs/design-rules.md` 要約）

Nexus 全体（iOS・公開サイト）に適用する。

- 余白: コンテンツ間16px、セクション20px、タップ領域44px以上
- 角丸: 通常16px、主要カード20px、ヒーロー/ボトムナビ外枠22-28px
- Material 3風 Elevation（`--elev-1/2/3`）、State layer、Ripple
- フォント: Noto Sans JP + Inter、数字は `tabular-nums`（**iOS アプリは SF Pro**）
- ライトテーマ固定、淡い空色グラデ背景 + 白カード + 弱い影
- `prefers-reduced-motion: reduce` では transform/animation を止め、色変化のみで状態表現
- UIは「1画面1主目的」。公開サイトの画面構成は #131 の情報設計に従う
- **iOS アプリとその Figma**：上のルールに従い、書いていないことは Apple の [HIG（iOS）](https://developer.apple.com/jp/design/human-interface-guidelines/designing-for-ios) に従う（2026-11-14 決定）。iOS は例外として背景は今のまま（systemBackground）、テーマはライト・ダークの両方に対応する。影と押下（Material 風）は iOS も全体のルールに揃える（2026-11-14 決定。`NexusElevation`・`NexusPressableButtonStyle` に移行済み）

新しいUIを実装・提案する際はこのルールに沿わせること。旧 PWA のデザイン資料（`web/DESIGN_SYSTEM.md` / `web/IMPLEMENTATION_GUIDE.md`）は 2026-10-25 に削除した（git 履歴から参照できる）。

## セキュリティ上、絶対に守ること

- 旧 `apps/admin-api` のデフォルト管理者パスワード（`AdminPassword123!`）はローカル開発専用のシード値だった。復元する場合も、本番設定や実際の秘密情報として絶対に使わない・コミットしない（`RequireSecret` はこの値を拒否する）。
- `appsettings.json` の `CHANGE_ME_TO_A_LONG_RANDOM_SECRET` のようなプレースホルダーは、本番デプロイ手順の提案時に必ず差し替えを促すこと。
- QRコード・トークン・個人情報（氏名・年齢・高校名など）をログや平文で保存するコードを書かない。
- 参加者ログの位置情報は「個人特定しない粒度」を保つ設計方針（`docs/overview.md`）。精度を上げすぎる変更は提案しない。

## ドキュメント参照先

| ファイル | 内容 |
|---|---|
| `docs/v1.0-scope.md` | v1.0の製品境界・必須成果・対象外・リリース条件の正本 |
| `docs/nexus-ai-ecosystem.md` | AIエコシステム全体方針・フェーズロードマップ |
| `docs/design-rules.md` | UIデザインルール |
| `docs/overview.md` | 公開サイト（`web/`）の方針・状況・未決事項 |
| `docs/security.md` | セキュリティ設計メモ（監査ログ。削除した QR/JWT の扱い） |
| `docs/phase1/route-ui-event-contract.md` | ルート表示UIイベント契約 |
| `docs/expo-sdk-54-migration.md` | 旧Expoアプリの移行記録（アーカイブ） |

## 今後の計画（TODO抜粋、詳細はREADME参照）

- Phase 1: ルート表示UI強化（ステップ案内・フロア跨ぎ・逸脱検知）、管理コンソールへのオペレーターハンドオフ
- E2Eテスト（Playwright想定）・Lighthouse/A11y改善
- ログ集約・分析ダッシュボード

## 作業時の基本姿勢

- 変更は小さく、レビューしやすい単位に分割する（チーム内でレビューできるのが実質1名のため）。
- 新しいライブラリやアーキテクチャパターンを導入する提案をする際は、必ず理由と代替案を添える（判断の移譲先がないため、記録が特に重要）。
- `web/` を参加者向けアプリとして拡張したり、iOS と機能同期したりしない。公開サイトの実装判断は #131 の範囲に従う。
- README・docs配下と実装が食い違っている場合は、黙って合わせるのではなく食い違いを指摘すること。
