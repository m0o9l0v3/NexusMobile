# 公開サイト（`web/`）の配信に必要なこと

- 状態: **NexusInfra への依頼メモ（未適用）**。NexusMobile からは設定を変えない。適用は NexusInfra 側でレビューしてから行う。
- 関係: [#131](https://github.com/m0o9l0v3/NexusMobile/issues/131)（公開サイト）、[#72](https://github.com/m0o9l0v3/NexusMobile/issues/72) と [E8-7](decisions/E8-7-production-cors-origins.md)（CORS）、[E8-1](decisions/E8-1-https-tls-termination.md)（TLS・HSTS）、NexusInfra `docs/pg17-edge-decisions.md` の DEC-3
- 作成: 2026-11-15

## 1. 決まっていること

| 項目 | 値 | 決定 |
|---|---|---|
| 公開サイトのドメイン | **`www.nexus-app.jp`**（public-api の `api.nexus-app.jp` と同じ親ドメインのサブドメイン） | #131、2026-11-15 利用者決定 |
| 公開サイトのオリジン | `https://www.nexus-app.jp` | 同上 |
| 配信の方法 | 既存 VPS の Caddy で静的ファイルとして配信する。追加契約なし | #131、2026-10-25 |
| ブラウザから呼ぶ API | public-api の `GET /health` だけ | #131、2026-11-14 |

## 2. NexusInfra でやること

### 2.1 DNS

- `www.nexus-app.jp` の A（と AAAA）を、`api.nexus-app.jp` と同じ VPS に向ける。

### 2.2 ビルドと置き場所

公開サイトはビルドすると静的ファイルだけになる（サーバーの処理は無い）。

```bash
cd web
npm ci
VITE_API_BASE_URL=https://api.nexus-app.jp npm run build   # web/dist/ に出力
```

- `VITE_API_BASE_URL` はビルド時に埋め込まれる。値を変えたら作り直す。
- `web/dist/` を VPS の決まった場所（例：`/srv/nexus-web/releases/<日時>/`）に置き、`/srv/nexus-web/current` をその版への**相対の**シンボリックリンク（`releases/<日時>`）にする。切り替えはリンクの付け替えだけで行い、前の版を残しておけば戻せる。
- Caddy のコンテナには、`current` ではなく**親の `/srv/nexus-web` を**読み取り専用でマウントする（例：`/srv/nexus-web:/srv/nexus-web:ro`）。`current` そのものをマウントすると、起動したときのリンク先が固定され、リンクを付け替えても新しい版に切り替わらない（戻すときも同じ）。親をマウントすれば、リンクはコンテナの中で解決される。
- お知らせ（`web/content/notices/`）や開発状況を更新したときも、作り直して置き換える。

### 2.3 Caddy のサイトブロック

`Caddyfile`（PG18）と `Caddyfile.pg17-api`（PG17 edge）のうち、本番で使う方に、次のようなブロックを足す。既存の `(headers)` をそのまま使う。

```caddyfile
{$SITE_DOMAIN} {
    import headers
    encode zstd gzip

    root * /srv/nexus-web/current

    # ファイル名にハッシュが付くので、長く持たせてよい
    @assets path /assets/*
    header @assets Cache-Control "public, max-age=31536000, immutable"

    # HTML は毎回確かめさせる（お知らせの更新をすぐ見せるため）
    @html path / /development/ /status/ /tech/ /privacy/ *.html
    header @html Cache-Control "no-cache"

    file_server
}
```

- 環境変数 `SITE_DOMAIN=www.nexus-app.jp` を Caddy のコンテナに渡す。
- ページは `/`・`/development/`・`/status/`・`/tech/`・`/privacy/` の5つで、それぞれ `index.html` を持つ。`file_server` は `/development` を `/development/` へ転送するので、書き換えの設定は要らない。
- QR の `?code=XXXX` はトップに着地する。値はサイトが使わないので、Caddy 側の設定は要らない。
- それ以外のパスは 404 になってよい（ルーターは使っていない）。

### 2.4 Content-Security-Policy（任意・推奨）

公開サイトが読み込む外部のものは、Google Fonts と public-api の `/health` だけである。付けるなら次の値になる。

```text
default-src 'self'; script-src 'self'; style-src 'self' https://fonts.googleapis.com; font-src https://fonts.gstatic.com; img-src 'self' data:; connect-src https://api.nexus-app.jp; base-uri 'self'; form-action 'none'; frame-ancestors 'none'
```

- 付ける場合は、公開前に4ページとライト・ダークで表示が崩れないこと、サーバー状況が「応答あり」になることを確かめる。

### 2.5 HSTS

- PG18 の `Caddyfile` は `includeSubDomains` 付き、PG17 の `Caddyfile.pg17-api` は付いていない（E8-1 の T-3）。`www.nexus-app.jp` も HTTPS だけで配信するので、どちらでも矛盾しない。`includeSubDomains` の採否は NexusInfra #9 の再検討どおり。

## 3. public-api の CORS

公開サイトのサーバー状況のページは、ブラウザから `https://api.nexus-app.jp/health` を呼ぶ。別のオリジンなので、public-api の CORS で公開サイトのオリジンを許可する必要がある。public-api 側は、許可を `GET /health` だけに絞るコードがすでに入っている（E8-7 の C-1）。

| 構成 | 今の設定 | 変える値 |
|---|---|---|
| PG18（`deploy/database/compose.production.yml`） | `Cors__AllowedOrigins__0: ${NEXUS_PUBLIC_ORIGIN}`（必須） | `NEXUS_PUBLIC_ORIGIN=https://www.nexus-app.jp` |
| PG17 edge（NexusInfra `compose.pg17-edge.yaml`） | `Cors__AllowedOrigins__0: https://${PG17_EDGE_API_DOMAIN}`（API 自身のオリジン＝実質だれも許可しない。DEC-3 案A） | `https://www.nexus-app.jp`。DEC-3 は「別オリジンのサイトが API を呼ぶ前に再判断する」としているので、**DEC-3 を案B（公開サイトのオリジンを1つ明示）へ改めてから**変える |

- 許可するのは `https://www.nexus-app.jp` の1つだけ。`http://`、末尾の `/`、親ドメイン（`https://nexus-app.jp`）は入れない。
- 変えたあと、次で確かめる。

```bash
# 許可される（Access-Control-Allow-Origin が返る）
curl -s -D - -o /dev/null -H 'Origin: https://www.nexus-app.jp' https://api.nexus-app.jp/health | grep -i access-control-allow-origin
# 許可されない（何も返らない）
curl -s -D - -o /dev/null -H 'Origin: https://evil.example' https://api.nexus-app.jp/health | grep -i access-control-allow-origin
```

- `/health` は GET だけを受け付ける。`curl -I`（HEAD）では 405 になり確かめられないので、上のように GET で送ってヘッダーだけを見る。

## 4. 公開前の確認

- [ ] `https://www.nexus-app.jp/`・`/development/`・`/status/`・`/tech/`・`/privacy/` が開く。`/development` は `/development/` へ転送される
- [ ] `https://www.nexus-app.jp/?code=TEST` でトップが出る
- [ ] サーバー状況が「応答あり」になる（ブラウザの開発者ツールで CORS のエラーが出ていない）
- [ ] HTTP で開くと HTTPS へ転送される
- [ ] スマホ（Safari）とPC、ライト・ダークで表示が崩れない
- [ ] アプリの画面画像（`web/public/app-shots/`）は承認済みのものだけが入っている
