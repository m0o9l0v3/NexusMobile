# E8-1: HTTPS / TLS は edge の Caddy で終端する

- 移行元ID: E8-1 / 区分: E8 / Issue: [#67](https://github.com/m0o9l0v3/NexusMobile/issues/67)
- 関係: #72（E8-7 CORS）、#107（E8-4 続き rate limit）、#131（公開サイト）、NexusInfra #5・#6・#7・#9、NexusInfra `docs/pg17-edge-decisions.md`（DEC-1〜3）
- 起案日: 2026-11-14
- 判断者: リポジトリオーナー（技術的意思決定者）
- 判断日: 2026-11-14（T-1〜T-3 は利用者決定、m0o9l0v3）
- 状態: **起案**。本書の PR のマージで §1〜§3 と §0.1 の決定を採用とする。§5 の T-4・T-5 は採用後も未決のまま残る。本番への適用は NexusInfra の手順と別承認による

## 0.1 決定（2026-11-14 利用者決定）

| ID | 決定 |
|---|---|
| T-1 | **案A を採用する**（Caddy が TLS を終端し、Let's Encrypt の証明書を HTTP-01 で自動取得・更新する。API は VPS 内部の HTTP だけ）。80 番を外部から開けられないと分かった場合は案B（DNS-01）を再検討する |
| T-2 | **`UseHttpsRedirection()` は残す**（R-1） |
| T-3 | **HSTS の `includeSubDomains` と `preload` は当面付けない**。同じドメインの下の全サイトが HTTPS で動くと確認してから NexusInfra #9 で再検討する |

判断の材料として利用者から示された事実：**オープンキャンパスの参加者など一般の来場者は、構内 Wi-Fi に接続できない**。構内 Wi-Fi を使うのは在校生・教職員だけである。したがって参加者の iOS アプリはキャリアのモバイル回線から API に届き、構内の TLS 中継（§5）は参加者には関係しない。

## 0. 要約

TLS の終端の方式は、NexusInfra の PG17 edge（`nexus-edge-pg17`）の設計で**事実上すでに決まっている**。Caddy がホストの 80/443 だけを公開し、Let's Encrypt の証明書を自動で取得・更新して TLS を終端し、API へは内部ネットワークの HTTP で転送する。本書はこの方式を NexusMobile 側の判断として記録し、API 側の設定（`UseHttpsRedirection` など）の扱いと、まだ決まっていない細目を整理する。

## 1. 現状（2026-11-14 確認）

### NexusMobile

| 項目 | 内容 | 出典 |
|---|---|---|
| API の待受 | 両 API のコンテナは HTTP 8080 だけで待ち受ける。証明書を持たない | `apps/public-api/Dockerfile`（`EXPOSE 8080`） |
| HTTPS への転送 | 両 API が `app.UseHttpsRedirection()` を呼ぶ。コンテナに HTTPS のポートが無いため、このミドルウェアは転送先のポートを決められず、実際には何もしない（起動時に警告を出すだけ） | `apps/public-api/Program.cs:106`、`apps/admin-api/Program.cs:142` |
| プロキシの情報 | `UseForwardedHeaders` で `X-Forwarded-For`・`X-Forwarded-Proto` を処理する。信頼するのは `RateLimiting:KnownNetworks`・`KnownProxies` から来た要求だけ | `docs/rate-limiting.md` |
| HSTS | API 側は `UseHsts()` を呼ばない | 同上の Program.cs |
| 本番 Compose（PG18 用の雛形） | API はホストの loopback にだけ公開し、HTTPS のリバースプロキシから接続する。プロキシ・DNS・証明書は VPS 側の導入作業に含める | `docs/production-database-runbook.md` |

### NexusInfra（PG17 edge、本番未適用）

| 項目 | 内容 | 出典 |
|---|---|---|
| 構成 | Internet → Caddy（ホストの TCP 80/443 だけ）→ `public-api:8080` → PG17。Caddy と public-api は `internal` の edge ネットワークでつながる | `docs/pg17-public-edge.md` §8、`compose.pg17-edge.yaml` |
| 証明書 | Caddy の automatic HTTPS（ACME）。HTTP から HTTPS への転送と証明書の更新も Caddy に任せる。証明書は Caddy の named volume に保存する | `docs/architecture.md`、`compose.pg17-edge.yaml` |
| ヘッダー | HSTS（`max-age` のみ。PG18 用の `Caddyfile` は `includeSubDomains` 付き）、`X-Content-Type-Options`、`Referrer-Policy`、`X-Frame-Options: DENY`、`Server` の削除 | `Caddyfile.pg17-api`、`Caddyfile` |
| 失敗時の扱い | HTTP-01 が失敗したら `nexus-edge-pg17` だけを止め、DNS・80 番の到達性を直してから再開する。Let's Encrypt は失敗が続くと発行を一時的に制限するため、何度も再試行しない | `docs/pg17-operator-checklist.md` D5 |
| 隔離検証 | 採用 digest で、Caddy 経由の HTTPS・CORS・偽装 `X-Forwarded-*` の扱いを隔離環境で確認済み（内部 CA を使った検証）。本番の証明書発行は未実施 | `docs/pg17-issue-7-digest-verification.md` |
| 後続 | Studio（`/api/*` と画面を同じ Caddy で配信）は NexusInfra #9。HSTS `includeSubDomains` の採否もそこで再検討する | NexusInfra #9 |

## 2. 選択肢

| 案 | 内容 | 長所 | 短所・リスク |
|---|---|---|---|
| **A：edge の Caddy で終端し、自動 ACME で証明書を取る（現行の NexusInfra 設計）** | Caddy が 80/443 を持ち、証明書の取得・更新・HTTP→HTTPS 転送を行う。API は内部ネットワークの HTTP だけ | 実装・隔離検証が済んでいる。証明書の更新を人が覚えておく必要がない。API に証明書・秘密鍵を置かない。公開サイト・Studio も同じ Caddy に足せる | 80 番を外部から開けておく必要がある（HTTP-01）。Caddy の設定ミスが全サイトに及ぶ |
| B：Caddy で終端し、DNS-01 で証明書を取る | 80 番を開けずに証明書を取れる | DNS 事業者の API トークンを VPS に置く必要がある。対応するプラグイン入りの Caddy を自前で build する必要がある | 秘密が1つ増え、Caddy のイメージを公式のものから外れる |
| C：Kestrel（ASP.NET Core）で直接 TLS を終端する | プロキシが不要 | 証明書の取得・更新を別に用意する必要がある。API ごとに証明書と秘密鍵を持つ。公開サイト・Studio の配信と 443 を分けられない | 1名の保守体制で更新を忘れる危険が大きい |
| D：Caddy で終端し、API までも TLS で暗号化する（再暗号化） | 内部ネットワークも暗号化される | 内部 CA と証明書の配布が必要 | 内部ネットワークは同一ホスト上の `internal` ネットワークで、得られる安全の増分が小さい |

## 3. 推奨

**案A を採用する。** あわせて API 側の扱いを次のとおりとする。

1. **HTTP→HTTPS の転送と HSTS は Caddy の責務とする。** API のコードに `UseHsts()` を加えない。ヘッダーを二重に付けると、値が食い違ったときにどちらが正しいか分からなくなるためである。
2. **`UseHttpsRedirection()` は残す**（推奨 R-1）。本番では Caddy が HTTPS だけを API に届け、`X-Forwarded-Proto: https` が信頼されるので、転送は起きない。開発環境の挙動も変えない。ただし、何もしていないことを本書に記録し、起動時の警告は既知のものとして扱う。
3. **API 間・Caddy と API の間は HTTP のままとする**（案D を採らない）。
4. **iOS の App Transport Security（ATS）の例外を設けない。** Caddy の既定は TLS 1.2 以上で、ATS の要件を満たす。iOS の `Info.plist` に `NSAllowsArbitraryLoads` などを加えない。
5. **公開サイト（`web/`）と Studio も同じ Caddy で終端する。** 80/443 を取り合う2つ目の Caddy は起動しない（NexusInfra #9 の要点と同じ）。

理由:
- 実装と隔離検証が NexusInfra で済んでおり、新たな作業が最も少ない。
- 証明書の更新を自動にでき、保守できる人が1名の体制（`CLAUDE.md`）に合う。
- API のコンテナに証明書・秘密鍵を置かずに済み、秘密の数が増えない。

## 4. 選ばなかった案

| 案 | 選ばなかった理由 |
|---|---|
| B：DNS-01 | 80 番を開けられない事情は確認されていない。DNS 事業者のトークンという秘密が増え、公式でない Caddy のイメージを保守する必要がある。80 番を開けられないと分かった場合に再検討する |
| C：Kestrel で終端 | 証明書の更新を別に作る必要があり、公開サイト・Studio と 443 を共有できない |
| D：内部も再暗号化 | 内部ネットワークは同一ホストの `internal` ネットワークで、内部 CA の運用の負担に見合わない |
| `UseHttpsRedirection()` を消す（R-2） | 起動時の警告は消えるが、開発環境の挙動が変わる。本番では効果が無いので、残しても消しても安全性は変わらない。消すなら別の小さな PR で行う |

## 5. オーナーが決めること（未決事項）

| ID | 論点 | 推奨 | 決める前に確かめる事実 |
|---|---|---|---|
| T-1 | 案A を NexusMobile の判断として採用するか | 採用する | なし（NexusInfra の設計と隔離検証は済） |
| T-2 | `UseHttpsRedirection()` を残すか（R-1）消すか（R-2） | R-1 残す | なし |
| T-3 | HSTS の `includeSubDomains` と `preload` を付けるか。PG18 用の `Caddyfile` と PG17 用の `Caddyfile.pg17-api` で値が違う | 公開サイト・Studio を含め、同じドメインの下の全サイトが HTTPS で動くと確認できるまで付けない。`preload` は付けない（取り消しに時間がかかる）。NexusInfra #9 で再検討する | 公開サイトのドメインが API と同じドメインの下か（§6 の #131） |
| T-4 | 証明書の期限切れの監視をどうするか | Caddy の自動更新に加え、外部から期限を確かめる仕組みを1つ置く（死活監視と同じ手段でよい）。手段は NexusInfra `docs/pg17-operator-checklist.md` D6 で決める | 監視に使えるサービス・費用 |
| T-5 | ACME の連絡先メールと、証明書の取得に失敗したときの対応 | NexusInfra D5 の合意（edge だけを止め、何度も再試行しない）をそのまま使う | 連絡先メール（値は私有メモに残し、Git に書かない） |

### 実機・VPS で確かめる事実（推測で埋めない）

- VPS のパケットフィルターで 80/443 を外部から開けられるか（NexusInfra `docs/pg17-public-edge.md` §5）。
- DNS の A / AAAA が VPS を指しているか。IPv6 の有無。
- 構内 Wi-Fi が外向きの HTTPS（443）を通すか、TLS を中継・検査する機器（プロキシ）が無いか。**参加者は構内 Wi-Fi に接続できない（§0.1）ため、参加者向けの前提ではない**。在校生・教職員が構内 Wi-Fi からアプリや公開サイトを使う場合にだけ影響するので、優先度は低い。

## 6. 他の Issue への影響

| Issue | 影響 |
|---|---|
| #72（CORS） | 許可する origin はすべて `https://` に限る。公開サイトが同じ Caddy で配信されることを前提に、同一 origin での中継という案を比べられる（E8-7 の判断記録） |
| #131（公開サイト） | 公開サイトのドメインを決めるとき、HSTS（T-3）と CORS（#72）の両方に効く |
| #107（rate limit） | Caddy を経由するため、クライアント IP は `X-Forwarded-For` と `KnownNetworks` に依存する（NexusInfra DEC-1 決定済み）。参加者が構内 Wi-Fi を使わないという事実は #107 にも効く（E8-4 r1） |
| NexusInfra #6・#7 | 本書の採用で変える設定は無い。T-3・T-4 の結果は NexusInfra 側の Caddyfile とチェックリストに反映する |
| NexusInfra #9 | T-3（HSTS `includeSubDomains`）を #9 の再検討で決める |
| `docs/production-database-runbook.md` | 「プロキシ・DNS・証明書の整備は VPS 側の導入作業に含める」の参照先として、本書と NexusInfra `docs/pg17-public-edge.md` を挙げる（採用後に直す） |
