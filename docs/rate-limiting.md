# Rate limiting（Issue E8-4）

admin-api / public-api は ASP.NET Core 標準の `Microsoft.AspNetCore.RateLimiting`（Fixed Window、クライアント IP 単位）でレート制限を行う。実装は `apps/admin-api/RateLimiting/RateLimitingExtensions.cs`（両 API 共通）。

## 対象と既定値

| ポリシー | 対象エンドポイント | API | 既定 |
| --- | --- | --- | --- |
| `auth-login` | `POST /admin/auth/login` | admin-api | 5 回 / 60 秒 |
| `code-redeem` | `POST /admin/one-time-codes/redeem` | admin-api | 10 回 / 60 秒 |
| `qr-landing` | `GET /q/{token}` | admin-api | 30 回 / 60 秒 |
| `log-ingest` | `POST /api/logs` | public-api | 60 回 / 60 秒 |
| `log-ingest-batch` | `POST /api/logs/batch`（最大 50 件 / リクエスト） | public-api | 12 回 / 60 秒 |

`/health` は対象外。JWT 認証済みの管理系エンドポイントと公開 GET 系は今回の対象外。

超過時は `429 Too Many Requests` + `Retry-After`（秒）ヘッダー + ProblemDetails を返す。

## 設定

`RateLimiting` セクション（環境変数では `RateLimiting__...`）。指定したキーだけが既定値を上書きする。

| キー | 内容 |
| --- | --- |
| `Enabled` | `false` で全ポリシーを無効化（既定 `true`） |
| `Policies:<name>:PermitLimit` / `WindowSeconds` | ポリシーごとの上限・ウィンドウ |
| `KnownProxies` / `KnownNetworks` | `X-Forwarded-For` を信頼するプロキシの IP / CIDR |

## クライアント IP

両 API とも `UseForwardedHeaders`（`X-Forwarded-For`, `X-Forwarded-Proto`、`ForwardLimit = 1`）を最初に実行する。信頼するのは `KnownProxies` / `KnownNetworks`（未設定時はループバックのみ）から来たリクエストだけで、それ以外の `X-Forwarded-For` は無視する（偽装による回避対策）。
本番でリバースプロキシ背後に置く場合は必ずプロキシの IP / ネットワークを設定すること。

## 既知の制約

- カウンターはプロセス内メモリで持つ。API を複数インスタンスにすると上限はインスタンスごとになる。
- イベント会場の共有 NAT からは複数端末が同一 IP に見える。`log-ingest*` の上限は運用実績を見て調整する。
- ログイン用の username 単位の制限は未実装（IP 単位のみ）。
