# E8-7: 本番の CORS 許可オリジン

- 移行元ID: E8-7 / 区分: E8 / Issue: [#72](https://github.com/m0o9l0v3/NexusMobile/issues/72)
- 関係: #131（公開サイト、`/health` の死活表示）、#67（E8-1 TLS 終端）、NexusInfra `docs/pg17-edge-decisions.md` DEC-3、NexusInfra #6・#7・#9
- 起案日: 2026-11-14
- 判断者: リポジトリオーナー（技術的意思決定者）
- 状態: **起案**。本書の PR のマージで §3 を採用とする。§5 の未決事項は採用後も未決のまま残る。コード・Compose の変更は別の PR で行い、本番への適用は NexusInfra の手順と別承認による

## 0. 要約

CORS が要るのは**ブラウザから別のオリジンの API を呼ぶ場合だけ**である。iOS アプリはネイティブなので CORS の影響を受けない。v1.0 でブラウザから API を呼ぶのは、公開サイト（`web/`）の `/health` の死活表示（#131）と、管理ポータル（`apps/admin-web`）を本番に置く場合の admin-api だけである。

推奨は、public-api では**公開サイトのオリジン1つだけを、`GET /health` に限って許可する**こと。あわせて、`appsettings.json` に残っている開発用のオリジンが本番でも有効になってしまう問題（§1.3）を直す。

## 1. 現状（2026-11-14 確認、develop `ce1f898`）

### 1.1 どのクライアントがブラウザから API を呼ぶか

| クライアント | 呼ぶ API | CORS が要るか | 根拠 |
|---|---|---|---|
| iOS アプリ（`apps/nexus-ios`） | public-api（`GET /api/v2/bundle`） | **要らない**（ネイティブの要求には CORS が無い） | `PublishedBundleRuntime.swift` |
| 公開サイト（`web/`） | public-api の `GET /health` だけ（#131 決定）。それ以外の API を使うかは #131 で未決 | **要る**（公開サイトと API のオリジンが違う場合） | `docs/overview.md`、#72 の 2026-10-25 のコメント |
| 管理ポータル（`apps/admin-web`） | admin-api（`VITE_ADMIN_API_BASE_URL`、既定 `http://localhost:5000`） | 管理ポータルを本番に置き、API と別オリジンにする場合だけ要る | `apps/admin-web/src/api/client.ts` |
| Studio（NexusStudio） | studio-api。同じドメインの `/api/*` を Caddy で振り分ける | 要らない（同一オリジン） | NexusInfra #9 |
| 旧 PWA | public-api のログ送信など | 2026-10-25 に削除済み。考えなくてよい | `docs/v1.0-scope.md` |

### 1.2 コードと設定

| 項目 | 内容 | 出典 |
|---|---|---|
| public-api のポリシー | `AllowFrontend`。`Cors:AllowedOrigins` のオリジンに、**全エンドポイント**で任意のヘッダー・任意のメソッドを許可する。credentials は許可しない | `apps/public-api/Program.cs:47-55,107` |
| admin-api のポリシー | `AdminPortal`。`Cors:Origins` のオリジンに、任意のヘッダー・メソッドを許可する | `apps/admin-api/Program.cs:89-97,144` |
| public-api の既定値 | `appsettings.json` に `http://localhost:5176` と `https://nexus.example.com` | `apps/public-api/appsettings.json:27-31` |
| admin-api の既定値 | `appsettings.json` に `http://localhost:5176` | `apps/admin-api/appsettings.json:45-47` |
| 開発用 Compose | public-api に `localhost:5176` と `nexus.example.com`、admin-api に `localhost:5176`（Issue 本文の「compose に残っている」はこれ） | `docker-compose.yml:13,27-28` |
| NexusMobile の本番雛形（PG18） | `Cors__AllowedOrigins__0: ${NEXUS_PUBLIC_ORIGIN}`、`Cors__Origins__0: ${NEXUS_ADMIN_ORIGIN}` を必須にしている | `deploy/database/compose.production.yml:33,51` |
| NexusInfra の PG17 edge（本番未適用） | DEC-3 案A（2026-10-18 決定）。`Cors__AllowedOrigins__0` は API 自身のオリジン（実質ブラウザ不許可）。別オリジンのサイトが API を直接呼ぶ前に再判断する、という条件付き | NexusInfra `compose.pg17-edge.yaml:13`、`docs/pg17-edge-decisions.md` DEC-3 |
| admin-api の公開 | NexusInfra の構成では admin-api を外部から到達させない | NexusInfra `docs/architecture.md` |

### 1.3 見つかった食い違い：開発用オリジンが本番でも残る

ASP.NET Core の設定は、配列を**添字ごとに**上書きする。本番では環境変数 `Cors__AllowedOrigins__0` が添字 0 だけを置き換え、`appsettings.json` の添字 1（`https://nexus.example.com`）はそのまま残る。`appsettings.Production.json` は CORS を上書きしていない。

- その結果、本番の public-api は意図しない `https://nexus.example.com` も許可していることになる（コードからの推定。隔離環境で確かめる。§5 C-5）。
- `example.com` は予約されたドメインで第三者が取れないため、いま実害は無い。ただし「設定した値だけが許可されている」という前提が崩れており、後で添字 1 に意味のある値を入れたときに混乱する。
- admin-api の既定値は1件だけなので、添字 0 の上書きで消える。

### 1.4 CORS で守れること・守れないこと

- CORS は、**ブラウザが**別オリジンのページに応答を読ませるかどうかを決めるだけである。curl やネイティブアプリ、ブラウザ以外からの要求は止めない。乱用への備えは rate limit（#107）が担う。
- `POST /api/logs` は JSON（`application/json`）を受けるため、許可していないオリジンのページからは事前確認（preflight）で止まる。許可するオリジンを広げると、そのオリジンのページからはログを送れるようになる。

## 2. 選択肢

### 2.1 public-api（公開サイトの `/health`）

| 案 | 内容 | 長所 | 短所・リスク |
|---|---|---|---|
| **P1：公開サイトのオリジンを1つ、`GET /health` だけに許可する** | `/health` 専用の CORS ポリシー（GET のみ、ヘッダー制限）を作り、`MapGet("/health")` に `RequireCors` で付ける。全体に効く既定のポリシーは外す | 許可の範囲が最小。公開サイトの用途（#131）にちょうど合う。オリジンが1つ増えても、ログ送信など他のエンドポイントは許可されない | public-api のコード変更（小）と、そのテストが要る |
| P2：公開サイトのオリジンを、今のポリシー（全エンドポイント・任意メソッド）に足す | 環境変数を1つ足すだけ | コード変更が無い | 公開サイトのページから `POST /api/logs` も呼べるようになる。#131 で他の API を使わないなら、必要以上に広い |
| P3：公開サイトから同一オリジンで中継する | 公開サイトの Caddy で `/<path>` を public-api の `/health` へ転送し、ブラウザからは同じオリジンに見せる | CORS が不要。オリジンの許可リストを空にできる | 表示が「ブラウザから API のドメインに届くか」ではなく「Caddy から API に届くか」になり、API のドメインの DNS・証明書の不具合を見落とす。Caddy の設定が増える |
| P4：オリジンを許可しない（DEC-3 案A のまま） | 変更なし | 最小 | #131 の死活表示がブラウザで読めず、常に「応答なし」になる。#131 の決定と合わない |
| P5：ワイルドカード（`*`） | 楽 | — | 任意のサイトからログ送信を呼べる。**不可**（DEC-3 と同じ） |

### 2.2 admin-api（管理ポータル）

| 案 | 内容 | 長所 | 短所・リスク |
|---|---|---|---|
| **A1：管理ポータルを本番に置くまで、許可オリジンを空にする** | 本番の admin-api は外部から到達できない（NexusInfra の構成）ので、許可するものが無い | 最小。現状の構成と一致 | 管理ポータルを本番に出すときに改めて決める必要がある |
| A2：本番に置くなら同一オリジンにする | 管理ポータルの静的ファイルと admin-api を、同じドメインの下で Caddy が振り分ける（Studio と同じ形） | CORS が不要。Cookie などの扱いも単純 | Caddy の設定が増える。管理ポータルの公開そのものが未決 |
| A3：本番に置くなら別オリジンで1つ許可する | 管理ポータルのオリジンを `NEXUS_ADMIN_ORIGIN` に入れる | 今の雛形のまま | 管理系の API を別オリジンから呼べるようにするので、範囲を慎重に決める必要がある |

## 3. 推奨

1. **public-api は P1 とする。** 許可するのは公開サイトの HTTPS オリジン1つだけ、`GET /health` だけ、credentials なし。
   - #131 で公開サイトが `/health` 以外の API（`GET /api/events/today` など）を使うと決めた場合は、その GET を個別に足す。ログ送信（POST）は許可しない。
   - 公開サイトと API が同じオリジンになる構成を選んだ場合は、許可リストを空にする。
2. **admin-api は A1 とする。** 管理ポータルを本番に置くと決めたときに、A2（同一オリジン）を第一候補として改めて決める。
3. **`appsettings.json` から開発用のオリジンを取り除く**（§1.3 の修正）。開発用の値は `appsettings.Development.json` と `docker-compose.yml` にだけ置く。`https://nexus.example.com` は開発環境でも使っていないので消す。
4. **ワイルドカードと `http://` のオリジンは本番で許可しない**（DEC-3 と同じ。NexusInfra の validator が拒否している）。

理由:
- iOS は CORS を必要としない。ブラウザから呼ぶ用途は `/health` の1つだけで、許可をそこに限れば、オリジンを足してもログ送信などの範囲は広がらない。
- P3 は CORS をなくせるが、死活表示が API のドメインの不具合を見落とすため、#131 の「ブラウザから届くか」という目的に合わない。
- §1.3 を直さないと、許可の範囲を設定から読み取れない。

## 4. 選ばなかった案

| 案 | 選ばなかった理由 |
|---|---|
| P2：今のポリシーにオリジンを足す | 公開サイトのページからログ送信まで呼べるようになり、#131 の用途より広い |
| P3：同一オリジンで中継 | 死活表示が「ブラウザから API に届くか」を表さなくなる。API のドメインの DNS・証明書の不具合を見落とす |
| P4：許可しない | #131 の死活表示が機能しない |
| P5：ワイルドカード | 任意のサイトからログ送信を呼べる |
| A3：管理ポータルを別オリジンで許可 | 管理ポータルを本番に置くかが未決。置く場合も A2 の方が範囲が狭い |

## 5. オーナーが決めること（未決事項）

| ID | 論点 | 推奨 | 決める前に確かめる事実 |
|---|---|---|---|
| C-1 | 公開サイトの `/health` を P1（`/health` だけを許可）にするか | P1 | なし |
| C-2 | 公開サイトの本番のオリジン（ドメイン） | — | #131 と NexusInfra で決める。API と同じドメインの下か（HSTS にも効く、E8-1 T-3） |
| C-3 | 公開サイトが `/health` 以外の public-api を使うか | #131 で決める。使う場合も GET だけを個別に足す | #131 |
| C-4 | 管理ポータル（`admin-web`）と admin-api を v1.0 の本番に置くか。置くならどのドメインか | 置くと決めるまで A1。置くなら A2 | `docs/v1.0-scope.md` は管理ポータルを v1.0 に含めるが、NexusInfra の構成では admin-api を外部に出していない。公開データの管理は Studio が担っている。この食い違いを先に解く（`CLAUDE.md` の「食い違いを指摘する」） |
| C-5 | §1.3（開発用オリジンが本番に残る）を直すか | 直す | 隔離環境で `Origin: https://nexus.example.com` を送り、`Access-Control-Allow-Origin` が返ることを確かめる（直す前の再現と、直した後の確認） |
| C-6 | NexusInfra DEC-3 を案A から案B（公開サイトのオリジンを1つ明示）へ改める時期 | 公開サイトの死活表示を本番で出す前 | DEC-3 の再判断条件「別オリジンのサイトが API を直接呼ぶ前」に当たる |

## 6. 採用後の作業と他の Issue への影響

| 対象 | 作業 |
|---|---|
| public-api（別 PR） | `/health` 専用の CORS ポリシーを作り `RequireCors` で付ける。全体に効く `UseCors("AllowFrontend")` の既定ポリシーを外すか空にする。許可オリジンからの `GET /health` に `Access-Control-Allow-Origin` が付き、`POST /api/logs` には付かないことをテストする |
| `appsettings.json`（両 API、別 PR） | 開発用のオリジンを `appsettings.Development.json` へ移し、本番の既定を空にする |
| `docker-compose.yml` | 開発用の `nexus.example.com` を消す |
| `deploy/database/compose.production.yml` | `NEXUS_PUBLIC_ORIGIN` の意味を「公開サイトのオリジン」と明記する。`NEXUS_ADMIN_ORIGIN` は C-4 の結果で残すか決める |
| NexusInfra（DEC-3、#6・#7） | C-6 の時期に DEC-3 を案B へ改め、`compose.pg17-edge.yaml` と validator・テストを直す。本番への適用は NexusInfra の手順と承認による |
| #131 | 公開サイトの `VITE_API_BASE_URL`（仮）と、死活表示の実装は本書の採用後に行う |
| #67（E8-1） | 許可するオリジンは `https://` に限る |
| #107 | P1 ではログ送信をブラウザに許可しないため、ブラウザ経由のログ送信の乱用は考えなくてよい |
