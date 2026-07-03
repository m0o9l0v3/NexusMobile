# Nexus API Foundation Policy

このドキュメントは、Nexus v1.0 初期リリース前の API 基盤に関する責務境界と変更ルールを固定するための方針文書です。

Issue #64 Phase 2 の成果物として、今後 Codex / Claude Code などの AI エージェントや人間の開発者が API 周辺を変更するときの判断基準として使用します。

---

## 1. 目的

Nexus の API 基盤では、管理者向けの `admin-api` と参加者向けの `public-api` を明確に分離します。

Phase 2 の目的は、以下を README / docs から参照できる状態に固定することです。

- `admin-api` と `public-api` の責務境界
- `public-api` の原則読み取り専用方針
- `visit_logs` への INSERT だけを例外書き込みとして認める方針
- public-api に認証・チェックイン・参加者識別を持たせない方針
- API 変更時に同時更新すべきファイル群

---

## 2. API の責務境界

### admin-api

`apps/admin-api` は管理者向け API です。

主な責務は以下です。

- 管理者認証
- JWT 発行・失効
- 管理者向け CRUD
  - spots
  - events
  - oc-days
  - departments / exhibits / timeslots などの管理データ
- 管理者向けログ閲覧
- 監査ログチェーン検証
- v1.0 hidden beta として残す QR issue / one-time code 系機能

`admin-api` は作成・更新・削除を担当できます。ただし、公開参加者向けの読み取り専用 API を兼ねてはいけません。

### public-api

`apps/public-api` は参加者向け公開 API です。

主な責務は以下です。

- 公開済みスポット情報の取得
- spot code による公開スポット解決
- 公開イベント情報の取得
- 近傍スポット検索
- ナビゲーション用 read model の提供
- ヘルスチェック
- 匿名参加者ログの受信

`public-api` は原則として読み取り専用です。

唯一の例外として、匿名参加者ログを `visit_logs` に INSERT することだけを許可します。

---

## 3. public-api に入れてはいけない責務

`public-api` には以下の責務を追加してはいけません。

- 管理者認証
- 参加者認証
- JWT 発行・失効
- チェックイン状態管理
- 参加者プロフィール管理
- 参加者識別
- QR issue の発行・失効
- QR token lookup
- one-time code の発行・引換
- 管理専用テーブルの読み取り
- `visit_logs` 以外への書き込み

QR 関連の正式なチェックイン機能が必要になった場合は、v1.1 以降で再設計します。v1.0 では public-api に認証・チェックイン責務を混ぜません。

---

## 4. public-api の書き込み例外

`public-api` で許可される書き込みは、`visit_logs` への INSERT のみです。

許可される経路は以下です。

```txt
POST /api/logs
POST /api/logs/batch
  ↓
LogsController
  ↓
LogPersistenceService
  ↓
visit_logs INSERT
```

この経路以外で `public-api` が DB を変更してはいけません。

禁止例:

- spot / event / oc-day の作成・更新・削除
- QR issue の scan count 更新
- token / revocation / one-time code 系テーブルの更新
- raw SQL による更新
- Entity Framework の `SaveChanges` を `LogPersistenceService` 以外で呼ぶこと

---

## 5. 公開データの原則

`public-api` が返すデータは、参加者に公開してよい read model に限定します。

原則:

- 未公開スポットを返さない
- 未公開イベントを返さない
- 管理者用メタデータを返さない
- 認証・トークン・QR発行・チェックイン系テーブルを返さない
- 参加者個人情報を扱わない

---

## 6. API 変更時の同時更新ルール

API の route / request / response / validation / enum を変更する場合、以下を同時に確認・更新します。

- Controller 実装
- DTO / response model
- OpenAPI
  - `openapi/public.yaml`
  - `packages/openapi/admin.yaml`
- client 実装
  - `packages/shared/src/api.ts`
  - `web/src/api/publicApi.ts`
  - `apps/mobile-ios`
  - `apps/sensor-lab-ios`
- mock-api
  - `mock-api/routes.json`
  - `mock-api/db.json`
- tests
  - `apps/public-api.Tests`
  - `apps/admin-api-tests`
- docs / README
  - root `README.md`
  - app-specific README
  - relevant docs under `docs/`
- CI checks

API 変更時に一部だけを変更して、OpenAPI / clients / docs / tests を放置してはいけません。

---

## 7. PR レビュー観点

API 周辺の PR では、最低限以下を確認します。

- `admin-api` と `public-api` の責務が混ざっていないか
- `public-api` に `visit_logs` 以外の書き込みが追加されていないか
- public-api が認証・チェックイン・参加者識別を担当していないか
- OpenAPI と Controller の route が一致しているか
- web / mobile / shared client が古い route を参照していないか
- mock-api が実 API と大きく乖離していないか
- README / docs が実装と矛盾していないか
- QR hidden beta 方針に反する主要導線が追加されていないか

---

## 8. 関連ドキュメント

- `docs/public-api-security-boundary.md`
- `docs/api-change-checklist.md`
- `docs/audit/v1.0-api-foundation-audit.md`
- `docs/deploy-public-api-readonly-role.md`
