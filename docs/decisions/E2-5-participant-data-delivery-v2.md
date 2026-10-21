# E2-5: 参加者向け公開データ配信契約 v2（草案）

- 移行元ID: E2-5 / 区分: E2 / 対応Issue: [#23](https://github.com/m0o9l0v3/NexusMobile/issues/23)（関連: #21, #22, #85）
- 状態: **草案（未承認）**。本文書の採用は、NexusStudio・NexusInfra 側の対応記録とあわせて技術的意思決定者が承認する。
- 起案日: 2026-10-20
- 承認済みの前提（2026-10-20 利用者判断）:
  - **DB境界は案b**：Studio が公開結果を配信用の表へ射影し、public-api はその表だけを読む。
  - **単一bundle**：地点と地図を1つのドキュメント・1つの版として配信する。
  - **地点の位置の正本は目的地Feature（O-1 案1）**：spot の位置は、`spot.id` と同じ canonical ID を持つ地図 Feature から解決する（§5.4）。
  - **種別と説明文は Spot の属性（O-2 K1＋D1）**：参加者向けの種別（閉じた集合）と任意の説明文を Studio の Spot 公開版に追加し、Spot 単独で公開する（S4-2、Studio 決定事項09）。
  - **ID alias の正本は Studio の追記専用台帳（O-3 A1）**：E1-3 の `spot_id_aliases` を Studio に実装し、bundle には解決先が公開中の alias だけを射影する（§5.5）。台帳は spot に限らず、**一度でも公開された ID と alias を記録する ID 予約表**とする（O-3b S2）。改名は「新しい ID の発行と旧 ID の廃止」として個別の管理コマンドで行い、alias の解決先は追記で更新する（O-3c R2＋T2）。iOS は bundle の外から来た ID だけを、データ層の解決器で1段だけ解決する（O-3d U2、§6 規則11）。
  - **大きさは硬い上限 10 MiB＋警告 2 MiB（O-4 S3）**、完全性の照合は ETag ではなく専用ヘッダー `Nexus-Bundle-Sha256` で行う（§3.4、§4.1.1）。
  - **更新確認は条件付き GET だけで行う（O-5 M1）**。manifest エンドポイントは作らない。O-4b の確認で 304 が成立しない場合に限り、`HEAD /api/v2/bundle` を追加する（§4.2）。
  - **古い bundle は v1.0 では削除しない（O-6 R1）**。見直しの条件と将来の削除の制約を §3.5 に定める。
  - **Studio の `studio` スキーマと配信用の `delivery` スキーマは同じ PostgreSQL データベースに置く**（§3.1）。
  - **admin-api の MapDataset draft API は廃止し、`map_datasets` 表と移行は残す（O-7 F3）**。表の削除は次に移行履歴が変わる機会にまとめる（§8.1）。
  - **経路グラフは bundle に含めて端末に保存する。ただし保存は P06（オフライン経路再計算）の保証を意味しない（O-8 G1）**（§5.6）。
  - **`GET /api/v2/bundle` には rate limit をかけず、サーバー側のキャッシュと端末側の再試行・確認頻度の規則で負荷に備える（O-9 L1）**（§4.1.2、§6 規則10）。
- 上位の決定: NexusStudio 決定事項28 v02 S4-1（地図の公開・復旧は Studio に一本化）、S4-2（Spot 属性と位置の公開単位の分離）、NexusStudio 決定事項10 §1（Spot のピン・階は地図版に含む）、E1-3（`Spot.Code == SpotDto.Id == canonical ID`、spot は MapDataset の対象を同じ ID で参照する read model）、E1-4（GeoJSON v1）、E1-5（WGS 84）。
- 前提となる別改訂: 目的地Featureの追加には E1-4 の改訂が必要である。改訂の草案は [E1-4 改訂1](E1-4-r1-destination-features.md)（GeoJSON payload 契約 2.0.0。版番号・種別の分け方・到達ノードの扱いは判断済みだが、改訂全体は未承認）であり、目的地種別・到達ノード・版番号の正本は同改訂側とする。

## 1. 目的と範囲

Studio で公開された地点・地図を、iOS が**単一の整合した版**として取得・保存・切替できるようにする。版の異なる地点・地図・経路グラフが端末内で混在しないことを、配信形式の構造で保証する。

対象:

- Studio の公開処理から配信表への射影（責任: NexusStudio）
- 配信表の権限（責任: NexusInfra 契約Bの改訂）
- public-api の配信エンドポイント（責任: NexusMobile #23）
- iOS が守る取得・検証・切替の規則（責任: NexusMobile #22）

対象外（本契約で決めない）:

- 初回同梱、有効期限、オフライン経路再計算の保証範囲（#83 P05/P06）
- イベント・開催回・カテゴリ・案内記事の配信（§10 で将来の拡張として扱う）
- 地図の描画方式（#24）、経路探索（#37）

## 2. 全体の流れ

```text
Studio 公開操作（1トランザクション）
  ├─ Release / ReleaseEntry / Publication を書く（既存）
  └─ 対象に spot または map が含まれる場合、同じトランザクション内で
       ├─ delivery.participant_bundles に新しい bundle 行を INSERT（不変）
       └─ delivery.current_bundle のポインタを UPDATE
        │
        ▼  nexus_public（SELECT のみ）
public-api  GET /api/v2/bundle
        │  ETag = bundle の SHA-256
        ▼
iOS  取得 → 検証 → 一時保存 → 原子的切替（旧版を1世代保持）
```

公開も復旧も、Studio では**常に新しい Release** になる（S4-5）。このため、配信側の版番号は単調に増加し、配信側に「戻す」操作は存在しない。public-api と iOS は publish・rollback を実装しない。

## 3. 配信表（案b）

### 3.1 スキーマ

配信用の専用スキーマ `delivery` を置く。`studio` スキーマの表構造の変更が public-api に波及しないようにするためである。

**前提：`delivery` は Studio の `studio` スキーマと同じ PostgreSQL データベースに置く。** §3.3 の「Release と同じトランザクションで射影する」は、PostgreSQL ではデータベースをまたいで成立しないためである。Studio の配置先（現行 PG17 の同じデータベースに `studio` スキーマを置く想定）は NexusInfra #8 の設計で確定し、この前提と食い違う場合は本契約を先に改訂する。

```sql
-- 所有: Studio のマイグレーション用 role（実名は Infra #8 で確定）
CREATE TABLE delivery.participant_bundles (
    bundle_version  bigint      PRIMARY KEY,        -- = studio.releases.sequence
    release_id      uuid        NOT NULL UNIQUE,    -- = studio.releases.release_id
    schema_version  text        NOT NULL,           -- payload 契約の版（例 '2.0.0'）
    payload         bytea       NOT NULL,           -- UTF-8 JSON。保存したバイト列をそのまま配信する
    sha256          char(64)    NOT NULL,           -- payload の SHA-256（小文字16進）
    byte_length     integer     NOT NULL,
    created_at      timestamptz NOT NULL
);

CREATE TABLE delivery.current_bundle (
    singleton       boolean     PRIMARY KEY DEFAULT true CHECK (singleton),
    bundle_version  bigint      NOT NULL REFERENCES delivery.participant_bundles(bundle_version),
    updated_at      timestamptz NOT NULL
);
```

- `payload` を `jsonb` にしないのは、PostgreSQL がキー順・空白を正規化してしまい、保存した SHA-256 と配信するバイト列が一致しなくなるためである。
- `bundle_version` に Release の sequence を使うので、spot/map を含まない Release（イベントだけの公開など）では bundle が作られず、版番号は飛び飛びになる。版番号の連続性を前提にしてはならない。

### 3.2 不変性と権限（Infra 契約Bの改訂案）

| role | `participant_bundles` | `current_bundle` |
|---|---|---|
| Studio runtime role | INSERT, SELECT | SELECT, UPDATE |
| `nexus_public` | SELECT | SELECT |
| その他 | 権限なし | 権限なし |

- `participant_bundles` に UPDATE・DELETE・TRUNCATE を誰にも付与しない。
- `current_bundle.bundle_version` を減らす UPDATE はトリガーで拒否する（単調増加の保証）。
- `nexus_public` が `studio` スキーマを読めないことは、契約Bのとおり維持する。
- 保持期間と削除の方針は §3.5。

### 3.3 射影の規則（Studio の責任）

1. 射影は Release を書くのと**同じトランザクション**で行う。途中で失敗した場合は Release も bundle も残らない（Studio の既存の公開保証に従う）。
2. bundle の内容は、その時点の `Publication` が `published` を指す全 spot と、公開中の地図1件から**全量で**組み立てる。差分配信はしない。
3. 組み立てた payload は §5 の不変条件を満たさなければならない。満たさない場合は公開そのものを失敗させる（Studio の公開前検証 `CandidateValidator` に追加する）。
4. 全ての spot が取り下げられた場合も、bundle を削除せず、空の `spots` を持つ新しい版を作る。
5. `id_aliases` は ID 予約表（§5.5）の alias の行から、alias ごとの最新の行を取り、その解決先が当該版で公開中の spot であるものだけを含める。
6. 組み立てた payload の大きさ（非圧縮の UTF-8 バイト数）を検査する（§3.4）。

### 3.4 bundle の大きさ（O-4 S3）

| 閾値 | 値 | 超えた場合 |
|---|---|---|
| 硬い上限 | **10 MiB**（10,485,760 バイト） | Studio は公開を失敗させる（公開阻止。Release も bundle も残らない） |
| 警告の閾値（絶対値） | **2 MiB**（2,097,152 バイト）。仮の値 | Studio の公開確認で警告する。公開は止めない |
| 警告の閾値（前版比） | 直前に公開した bundle の **1.5倍** 以上。仮の値 | Studio の公開確認で警告する。公開は止めない。直前の版がない最初の公開では使わない |

- 大きさは**非圧縮の UTF-8 バイト数**（`participant_bundles.byte_length`）で測る。圧縮後の大きさでは測らない。
- 硬い上限は、地図 payload の既存の上限 8 MiB（`MapDatasetValidator`）に spots・alias の余裕 2 MiB を足した値である。地図の上限を変える場合は、この値もあわせて見直す。
- 警告は、重複や頂点数の誤りによる肥大を公開前に発見するためのものである（O-4a A4）。絶対値の 2 MiB は v1.0 の見込み（非圧縮で約 0.3〜1 MB、推定・未計測）の2倍程度として置いた。前版比は、見込みのずれに関係なく急な増加を見つけるために置く。経路グラフを初めて入れるときなど、正当な増加でも前版比の警告は出るが、公開は止めないので管理者が確認して公開できる。
- **実測と見直し**：経路グラフ（#32・#39）を含む最初の実データで大きさを実測し、絶対値の閾値と前版比の倍率を見直す。担当は #23 と Studio。現時点では原本がリポジトリ外にあり、CLI も建物の暫定 Polygon しか出せないため、意味のある実測はできない。
- **合成データによる事前確認**：実データを待たずに、上限付近（8〜10 MiB）の合成 bundle で iOS の受信・デコード・保存の負荷を #22 の試験で確かめる。合成データは試験専用とし、実データ・fixture の正式データとは区別する。問題があれば硬い上限の見直しにつなげる。
- iOS の受信時の扱いは §6 規則8。


### 3.5 古い bundle の保持（O-6 R1）

**v1.0 では `participant_bundles` の行を削除しない。** 理由は次のとおり。

- iOS も public-api も古い版を取得しない（現在の版だけを配信し、版を戻さない）。Studio の復旧は新しい Release を作るため、古い bundle の行は復旧に使わない。古い行の用途は「ある時点で来場者に配信されていたバイト列」の確認（障害調査・説明責任）である。
- 公開履歴の正本は Studio の `Release`・`ReleaseEntry`・各 Revision であり、配信表はその射影である。
- v1.0 の見込み（spot・地図を含む公開だけで bundle が増え、1件あたり非圧縮で約 0.3〜1 MB、PostgreSQL の TOAST 圧縮あり）では保存量が小さく、削除の仕組みを作る費用に見合わない。見込みは推定である。
- 削除しないことで、§3.2 の「追記専用・UPDATE と DELETE を誰にも与えない」をそのまま保てる。

**見直しの条件**：配信表の合計が **1 GiB** を超えた、または行数が **500 件**を超えたら、削除の方式（件数で保持するか、期間で保持するか）を決める。値は推定にもとづく仮の値であり、運用の実測で見直す。NexusInfra の監視（ディスク・バックアップの大きさ）に配信表の大きさを含める。

**将来削除するときの制約**（方式を決める前から固定する）:

1. `current_bundle` が指す版は削除しない。
2. 削除は Studio・public-api の実行時 role ではなく、所有者 role によるレビュー済みの手動手順で行う。実行時 role に DELETE を与えない。
3. 配信表の行を削除しても、Studio の Release 履歴・Revision は削除しない。
4. 行の一部（`payload` だけ等）を消す更新はしない。削除するときは行ごと削除する。

## 4. HTTP API（public-api）

### 4.1 `GET /api/v2/bundle`

現在公開中の bundle を返す。認証なし・読み取り専用。rate limit のポリシーは付けない（§4.1.2）。

**リクエストヘッダー**

| ヘッダー | 用途 |
|---|---|
| `If-None-Match` | 端末が保持している版の ETag |

**200 OK**

| 項目 | 値 |
|---|---|
| Body | `participant_bundles.payload` のバイト列そのもの |
| `Content-Type` | `application/json; charset=utf-8` |
| `ETag` | `"sha256-<sha256>"`（strong）。**条件付き GET 専用**（§4.1.1） |
| `Nexus-Bundle-Sha256` | `sha256`（小文字16進64桁）。**完全性の照合専用**（§4.1.1） |
| `Nexus-Bundle-Version` | `bundle_version`（10進） |
| `Nexus-Bundle-Schema` | `schema_version` |
| `Nexus-Bundle-Length` | `byte_length`（非圧縮の UTF-8 バイト数、10進） |
| `Cache-Control` | `no-cache`（保存してよいが、使う前に再検証が必要） |

- public-api は応答を圧縮しない。圧縮は edge の Caddy（`encode zstd gzip`）が担当する。
- public-api は送信前に `payload` の SHA-256 を再計算し、`sha256` 列と一致しなければ 500 を返す（§4.3）。中身の妥当性（§5）を public-api は再検証しない。それは Studio の責任である。

**304 Not Modified**：`If-None-Match` が現在の ETag と一致した場合。Body なし。`ETag`・`Nexus-Bundle-Sha256`・`Nexus-Bundle-Version` を付ける。

#### 4.1.1 ETag と照合ヘッダーの役割分担

edge のプロキシが応答を圧縮するとき、ETag の値を書き換える（例：符号化名の接尾辞を付ける、weak にする）ことがある。採用中の Caddy v2.11.4 の正確な挙動は未確認（§11 O-4b）であるため、完全性の照合を ETag に依存させない。

| ヘッダー | 用途 | iOS の扱い |
|---|---|---|
| `ETag` | 条件付き GET の鍵 | 受け取った値を**解釈せずにそのまま**保存し、次回の `If-None-Match` に送る。値から SHA-256 を取り出さない |
| `Nexus-Bundle-Sha256` | 受信した bundle の完全性の照合 | 圧縮を展開した後のバイト列の SHA-256 と一致することを確かめる |

- `Nexus-Bundle-Sha256` は public-api が `participant_bundles.sha256` から付け、edge は変更しない。
- 中継で `Nexus-Bundle-Sha256` が失われた場合、iOS は検証できないものとして bundle を採用しない。


#### 4.1.2 負荷への備えと rate limit（O-9 L1）

- `GET /api/v2/bundle` には rate limit のポリシーを付けない。公開 GET を対象外とする現行方針（`docs/rate-limiting.md`）と同じである。構内 Wi-Fi の NAT で多くの来場者が1つの外向き IP を共有する可能性があり、IP 単位の上限は正当な来場者を止めうるためである。構内の外向き IP の構成は未確認である。
- public-api は現在の版の bytes とヘッダーを `bundle_version` を鍵にメモリに保持する。リクエストごとに DB から読むのは `current_bundle` の版番号だけとし、版が変わったときだけ `participant_bundles` から読み直す。読み直し時も §4.1 の SHA-256 の再計算を行う。
- 応答は全員に同じ内容で、更新がなければ 304 になる。乱用の影響は帯域に限られるため、帯域と 200 応答の件数を監視して検知する。
- **予備策（未導入）**：乱用を観測した場合に限り、IP ごとの緩い上限（既存のポリシーの仕組みへの追加）を導入する。値は観測と構内ネットワークの事実確認にもとづいて決める。

### 4.2 更新の確認（O-5 M1、条件付きで HEAD を追加）

更新の確認と取得は、`GET /api/v2/bundle` への条件付き GET（`If-None-Match`）1回で行う。更新がなければ 304（本体なし）、あれば同じ応答で本体を受け取る。確認と取得が1回の応答なので、その間に別の版が公開されて食い違うことがない。manifest（版・ハッシュ等を返す JSON）のエンドポイントは作らない。

**条件付きの追加：`HEAD /api/v2/bundle`**

O-4b の隔離確認で、edge を経由すると 304 が成立しない（ETag の書き換え等で `If-None-Match` が一致しない）と分かった場合に限り、次を追加する。

- 同じ URL への HEAD に、GET の 200 と同じヘッダー（`ETag`・`Nexus-Bundle-Sha256`・`Nexus-Bundle-Version`・`Nexus-Bundle-Schema`・`Nexus-Bundle-Length`・`Cache-Control`）を本体なしで返す。エラー時の Status も GET と同じとする。ASP.NET Core の `[HttpGet]` は HEAD に応答しないため、`[HttpHead]` を明示する。
- iOS は HEAD の `Nexus-Bundle-Sha256` が保存済みの版と同じなら取得しない。違う場合だけ GET で本体を取得する。
- HEAD の結果は「取得するかどうか」の判断にだけ使い、**取得した bundle の正しさの根拠にしない**。取得した本体は、その GET 応答自身のヘッダーで §6 規則2 のとおり照合する。HEAD と GET の間に新しい版が公開されても、取得した本体が自身のヘッダーと一致すれば採用してよい。
- ヘッダーだけの追加なので、schema のマイナー版として後から導入できる。

### 4.3 エラー（RFC 9457 Problem Details）

| 状況 | Status | `type` |
|---|---|---|
| まだ一度も bundle が公開されていない | 404 | `urn:nexus:problem:bundle-not-published` |
| DB に接続できない・タイムアウト | 503（`Retry-After` 付き） | `urn:nexus:problem:bundle-unavailable` |
| `sha256` の不一致（保存データの破損） | 500 | `urn:nexus:problem:bundle-integrity` |
| rate limit 超過 | 429（`Retry-After` 付き） | 本エンドポイントにはポリシーを付けないため通常は返らない。将来 §4.1.2 の予備策を導入した場合、または edge が返した場合に iOS は §6 規則10 に従う |

- 「未公開」（404）と「取得できない」（503）を区別する。iOS は 404 を「掲載なし」、503 を「通信できない」として表示し分ける。
- 応答・ログに接続文字列・内部例外・個人情報を含めない。

### 4.4 既存エンドポイントとの関係

| エンドポイント | 扱い |
|---|---|
| `/api/navigation/spots[/{id}]`, `/api/floors`, `/api/routes` | v2 公開後、#21 で撤去する。利用者は `web/src/app/App.tsx` と `packages/shared/src/api.ts` で、iOS は使っていない |
| `/api/spots/public`, `/api/spots/by-code/{code}` | Studio による `spots.is_published` の廃止（28 v02 §5）と旧データへの射影（Step 5〜6）が決まるまで維持する。iOS はこれらを使わない |
| `/api/events/today`, `/api/nearby`, `/api/logs*` | 本契約では変更しない |

## 5. Payload 契約（`schema_version` 2.0.0）

### 5.1 構造

```json
{
  "nexus_bundle": {
    "schema_version": "2.0.0",
    "bundle_version": 42,
    "release_id": "0192f0a1-....",
    "published_at": "2026-11-01T09:00:00Z"
  },
  "spots": [
    {
      "id": "mb_2f_rm_001",
      "name": "教室 2A",
      "kind": "classroom",
      "description": null,
      "search_aliases": ["2A", "にーえー"],
      "utilization": "available",
      "placement": {
        "feature_type": "room",
        "building_id": "mb",
        "floor_id": "mb_2f",
        "point": [139.000000, 35.000000],
        "access_node_id": "mb_2f_n_012"
      }
    },
    {
      "id": "mb",
      "name": "教室棟",
      "kind": null,
      "description": null,
      "search_aliases": [],
      "utilization": "available",
      "placement": {
        "feature_type": "building",
        "building_id": "mb",
        "floor_id": null,
        "point": null,
        "access_node_id": null
      }
    }
  ],
  "id_aliases": [
    { "alias": "mb_f2_cr_2a", "canonical_id": "mb_2f_rm_001" }
  ],
  "map": {
    "dataset_version": 7,
    "dataset_sha256": "…64桁…",
    "geojson": { "type": "FeatureCollection", "nexus": { "schema_version": "2.0.0", "floors": [] }, "features": [] }
  }
}
```

（値は形式を示す例で、実データではない。）

### 5.2 項目

**`nexus_bundle`**（必須）

| 項目 | 型 | 規則 |
|---|---|---|
| `schema_version` | string | 本契約の版。SemVer |
| `bundle_version` | integer | `Nexus-Bundle-Version` ヘッダーと一致 |
| `release_id` | string (UUID) | Studio の Release ID |
| `published_at` | string (RFC 3339, UTC) | Release の作成日時 |

bundle 自身のハッシュは payload に含めない（循環するため）。ハッシュは `ETag` で受け取る。

**`spots[]`**（必須。空配列可）

| 項目 | 型 | 必須 | 出典 | 規則 |
|---|---|---|---|---|
| `id` | string | 必須 | Studio `Spot.CanonicalId` | canonical ID。大文字小文字を区別する完全一致。bundle 内で一意 |
| `name` | string | 必須 | Spot 公開版 `Name` | 表示名。ID から生成しない |
| `kind` | string \| null | 必須（null可） | Spot 公開版 `Kind`（**Studio に追加が必要**） | 参加者向けの種別。閉じた集合で、初期の候補は `classroom` / `facility` / `service`（下記「`kind` の規則」、O-2a。#84・#83 P12 の承認待ち）。null は「種別未設定」。**契約上は null 可のまま維持する**。公開時に必須とするかは Studio の公開前検証の規則とし、#84 で候補が承認されるまでは警告、承認後は公開阻止とする（O-2c C4） |
| `description` | string \| null | 必須（null可） | Spot 公開版 `Description`（**Studio に追加が必要**） | 来場者向けの任意の短い説明。イベントの説明とは別（Studio 決定事項09）。未作成は null とし、空文字や仮文で埋めない |
| `search_aliases` | string[] | 必須（空可） | Spot 公開版 `Aliases` | 名称検索用の別名。**ID の alias（`id_aliases`）とは別物** |
| `utilization` | string | 必須 | Spot 公開版 `Utilization` | `available` / `noNewSelection`。`withdrawn` の spot は bundle に含めない |
| `placement` | object \| null | 必須（null可） | **目的地Feature**（§5.4） | null は「公開中の地図に同じ ID の目的地Featureがない」。推測で埋めない |
| `placement.feature_type` | string | 必須 | 目的地Feature | 解決元 Feature の `properties.feature_type`（§5.4 の目的地種別のいずれか） |
| `placement.building_id` | string | 必須 | 目的地Feature | `map.geojson` 内の `building` Feature の `id`。解決元が `building` の場合は自分自身の `id` |
| `placement.floor_id` | string \| null | 必須（null可） | 目的地Feature | `map.geojson.nexus.floors[].id`。建物・屋外の目的地は null |
| `placement.point` | [lon, lat] \| null | 必須（null可） | 目的地Feature | 解決元が Point の場合はその座標（WGS 84、小数6桁、E1-5）。`building`（Polygon）の場合は null とし、重心などを推測して埋めない |
| `placement.access_node_id` | string \| null | 必須（null可） | 目的地Feature | 経路探索の到達先ノード（`indoor_node` / `outdoor_node`）。経路グラフが未公開の間は null（§11 O-1d） |

`placement` は Studio が射影時に目的地Featureから解決して書き込む**派生値**であり、正本は `map.geojson` の Feature である。iOS が `map.geojson` から自分で解決し直す必要はないが、§5.3 の不変条件で両者の一致を検査できる。

建物名・階名の表示は、`placement` から `map.geojson` の `building.properties.name` と `nexus.floors[].name` を参照して得る。spot 側に表示名を重複して持たない（Studio の `BuildingName` / `FloorName` 文字列は S4-2 により配信の正本にしない）。

`kind` の規則:

- `kind` は Spot の属性であり、目的地Featureの型（Studio 決定事項26 の `cl` / `cr` / `wc` / `rm`、`building` 等）から**導出しない**。表示上の分類を ID の命名規則に結び付けないためである。Studio の編集画面が型コードから初期値を提案することは妨げないが、公開されるのは管理者が確定した値だけとする。
- **展示（exhibit）は地点の種別に含めない（O-2b E1）。** 展示・イベントは地点の属性ではなくイベントの性質として扱い、iOS の既存の `MapSelection.eventID`・`SpotEventContext`・`AppRouteRequest.eventDetails` で地点に関連付ける。1つの地点で複数の展示が行われる形もこれで扱える。
  - iOS の `SpotKind.exhibit`（定義と表示名だけで使用箇所なし）は、#22 の bundle 接続の PR で削除する。
  - 探すでイベント（展示・ブース）を結果に含める場合、地点と区別する「結果の型」は #27 で設計し、地点の `kind` には混ぜない。
  - 常設展示のエリアを独立した種別にする必要が出た場合は、#84 の判断を経てマイナー版で追加する。
- 候補の集合への値の追加はマイナー版とする。iOS は同じメジャー版の中で未知の `kind` を受け取っても bundle を拒否せず、種別を表示しない（他の地点の表示を止めない）。
- **null と未知の値の扱い（O-2c C4）**：iOS は `kind` が null の場合も、未知の値の場合と同じく種別を表示しない。iOS の `SpotSummary.kind` は「種別なし」を表せる型にする（#22）。iOS は未知の値のためにどのみち「種別なし」を扱う必要があるため、契約を null 不可にしても読み手の利点は小さい。そこで契約は null 可のまま変えず、種別を必須とするかは Studio の公開前検証の規則で決める（契約の版を上げない）。
- **公開時の検査（O-2c C4）**：Studio は、#84 で候補の集合が承認されるまでは種別のない Spot の公開時に警告し、公開は止めない。承認後は公開を止める。切り替えは Studio の設定または版で行い、本番で最初に公開する前に既存の Spot に種別を付ける。
- **初期の候補（O-2a。#84 の Figma `2622:818` の承認と #83 P12 の決定を待つ）**：`classroom` / `facility` / `service` の3つ。値は iOS の `SpotKind` の raw value と同じであり、探すのカテゴリチップ（`SearchCategoryID`）とも一致する。値を増やすのはマイナー版でできるため、少数で始める。
- **割り当ての指針**（Studio で種別を付けるときの目安。正本ではなく、Studio が初期値を提案するときに使う。線引きは #84 の承認で見直す）：

  | `kind` | 表示 | 主な対象 |
  |---|---|---|
  | `classroom` | 教室 | 授業・体験が行われる教室・実習室 |
  | `facility` | 施設 | 建物・正式入口・ランドマーク・トイレ・その他の室 |
  | `service` | サービス | 受付・保健室・救護など、来場者に応対や支援を行う場所 |

- トイレを独立した種別（`restroom`）にするかは、探すのカテゴリチップの追加と一体の判断として #84 で検討する（§11 O-2a）。

`description` は Spot 単独で公開する属性（S4-2）であり、地図の公開版とは独立して更新される。単一 bundle のため、どちらが更新されても新しい版として全量が配信される。

`description` の運用（O-2d D-1）:

- 説明文の供給元・確認者・公開者・更新頻度は **#49** で決める。#49 の範囲（2026-09-07 の承認済み差分）は展示・開催時間・受付等の原稿の供給体制を含み、説明文も同じ来場者向けの原稿として扱う。本契約は組織上の役割を定めない。
- **#49 が決まるまで、Studio は説明文を公開しない。** bundle の `description` は null になる。これは運用上の取り決めとし、Studio の入力欄を無効にするなどの技術的な制限は設けない（必要になれば別途判断する）。
- 開発チームは、正式な原稿の代わりとなる文を書かない（#84「正式情報と誤認する仮表示を残さない」）。
- Studio は1人の管理者で編集から公開まで完結できる（Studio 決定事項06）。公開前に別の人の確認を必須にするかは #49 で組織の運用として決め、Studio に確認の機能を追加するかは別の判断とする。
- #49 の結果として、v1.0 では説明文を使わない（常に null）と決めることもできる。

**`id_aliases[]`**（必須。空配列可）：E1-3 の規則6（旧ID を alias として残す）に対応する。出典は Studio の ID 予約表（§5.5）の alias の行。

| 項目 | 型 | 規則 |
|---|---|---|
| `alias` | string | 旧ID。大文字小文字を区別する完全一致 |
| `canonical_id` | string | 解決先の現行 canonical ID。`spots[].id` に存在する |

`alias` → `canonical_id` の解決は1段のみで、連鎖させない。台帳の全件ではなく、**解決先がこの版で公開中の spot である alias だけ**を含む。iOS はこの表を、bundle の外から来た ID の解決にだけ使う（§6 規則11）。

**`map`**（object | null）：null は「公開中の地図がない」。

| 項目 | 型 | 規則 |
|---|---|---|
| `dataset_version` | integer | Studio `MapDataset.Version` |
| `dataset_sha256` | string | Studio `MapDataset.Checksum`（payload 文字列の SHA-256） |
| `geojson` | object | E1-4 の GeoJSON v1。Studio の publish validator に合格したもの。経路グラフ（`walking_path`・`indoor_node`・`outdoor_node`）を含む（§5.6） |

### 5.3 不変条件（Studio が射影時に保証し、iOS が受信時に検査する）

1. `spots[].id` は一意。比較は大文字小文字を区別する。
2. `id_aliases[].alias` は bundle 内で一意で、どの `spots[].id`、`map.geojson` の Feature の `id`、`nexus.floors[].id` とも一致しない。`canonical_id` は `spots[].id` に存在する。取り下げた spot・未公開の spot を指す alias は含めない。
3. `placement` が null でない場合、`map` は null でなく、`map.geojson` に `id == spots[].id` かつ目的地種別（§5.4）の Feature が1件だけ存在する。`placement` の各値はその Feature の値と一致する。`building_id` と `floor_id` は `map.geojson` に存在し、`floor_id` の所属建物は `building_id` と一致する。`access_node_id` が null でない場合、その node が `map.geojson` に存在する。
   - `placement` が null の場合、`map.geojson` に `id == spots[].id` の目的地Featureは存在しない（解決できるのに null にしない）。
4. bundle に含まれるのは、Studio の `Publication` が `published` を指す spot だけである。未公開・取り下げ済みの spot と ID は含めない。
5. 地図に含まれない ID・未知の ID を、受付など別の地点へ置き換えない（iOS の `unknownSpot` 表示を維持する）。
6. `bundle_version` は過去に配信したどの版よりも大きい。

### 5.4 目的地Featureによる位置の解決（O-1 案1）

spot の位置・建物・階・到達ノードの正本は、**`spot.id` と同じ canonical ID を持つ地図 Feature**（目的地Feature）とする。これは E1-3 の「spot は MapDataset の対象を同じ canonical ID で参照する read model」と、S4-2・Studio 決定事項10 §1（ピン・階は地図版に含む）をそのまま適用したものである。

目的地種別（spot の解決元になれる `feature_type`）:

| `feature_type` | 状態 | geometry | 用途 |
|---|---|---|---|
| `building` | E1-4 v1 で既存 | Polygon | 建物を目的地にする場合。Feature 自身が位置 |
| `formal_entrance` | E1-4 v1 で既存 | Point | 正式入口を目的地にする場合 |
| `room` / `landmark` | **E1-4 改訂1 で追加（草案）** | Point（部屋の外形は将来、別種別で追加） | 屋内の部屋・諸室、屋外のランドマーク |

- 新しい種別の名称・分け方は E1-4 改訂1 で `room` / `landmark` の2種を提案している（§11 O-1a）。
- `walking_path`・`indoor_node`・`outdoor_node` は経路グラフの要素であり、目的地種別に含めない。ノード ID を spot の ID にしない。E1-4 v1 の `node_kind: destination`（スポットとして公開可能なノード）は、E1-4 改訂1 で「目的地Featureの到達ノード」の意味に改める案である。
- 1つの canonical ID に目的地Featureは1件だけ存在する（E1-4 規則5の種別横断一意による）。
- 目的地Featureの表示名の正本は Spot 公開版の `name` とし、`room` / `landmark` には `name` を持たせない案を E1-4 改訂1 で提案している（§11 O-1c）。`building` Feature の `name` は現行どおり建物名として使う。
- spot として公開されていない目的地Featureが地図にあってもよい（例：Spot 未登録の部屋）。逆に、目的地Featureがない spot は `placement: null` で配信する。

段階的な導入:

- E1-4 改訂前でも、目的地を `building` / `formal_entrance` に限れば、スキーマ v1.0.0 のまま本方式で位置を解決できる。これは別方式ではなく、本方式の部分集合として扱う。
- 屋内の部屋・施設の点は、どの方式でも #36（フロアごとのアンカーと floor-local 座標）が揃うまで公開できない。本方式の採用はこのデータ不足を解消しない。

### 5.5 ID 予約表と alias（O-3 A1、O-3b S2）

alias の正本は、Studio に実装する**追記専用**の台帳とする。E1-3「alias 方針」の設計（`spot_id_aliases`）を、置き場所だけ nexus-mobile の DB から Studio へ移して適用する（S4-1 により spot・地図の正本が Studio にあるため）。

台帳の対象は spot の alias に限らず、**一度でも公開された canonical ID（spot・建物・フロア・ノード・辺・入口・部屋・ランドマーク）と alias を1つの表に記録する ID 予約表**とする（O-3b S2）。E1-3 の「全 MapDataset canonical ID と全 alias を単一の予約済み名前空間として管理する」、E1-2 の「廃止した ID は再利用しない」（l.59・l.80）と「公開済み ID の改名は alias／移行対応を記録する」（共通規則6）を1つの仕組みで満たすためである。ノード・フロアなどの ID も bundle の `map.geojson` に入って配信されるため、E1-2 の規則が実際に効く。

- **版管理しない**。行の追加だけを許し、変更・削除をしない（E1-3「外部参照に使われた可能性がある alias は削除しない」）。Spot や地図を過去の版へ復旧しても（S4-5）、alias は消えない。
- **最低限の項目**：`id`（canonical ID または旧ID）、`entity_kind`（spot・building・floor・indoor_node・outdoor_node・walking_path・formal_entrance・room・landmark）、`state`（`active`：現役 / `retired`：廃止 / `alias`：旧ID）、`alias` の解決先（参照方法は O-3c で決める。下記）、`created_at`、登録の根拠（公開の Release ID、改名操作の ID、または取り込み元）。
- **登録の時点**：地図・spot の公開と同じトランザクションで、新しく公開された ID を `active` として追加する。公開版から消えた ID は削除せず、`retired` の行を追記する（行の変更はしない。状態の変化は行の追記で表す）。**draft の ID は登録しない**。一度も公開されなかった ID を永久に予約しないためである。draft との衝突は検証時に現在の draft と照合する（E1-3）。
- **alias の解決先の持ち方（O-3c T2）**：解決先は canonical ID で持ち、**追記で更新する**。旧 ID B を新 ID C へ改名するとき、`B → C` の alias 行に加えて、B を解決先にしている既存の alias（例 A）すべてについて `A → C` の行を追記する。同じ alias では**最新の行を有効**とする。これにより、A→B の後に B→C と改名しても連鎖（A→B→C）が生じず、追記専用も保たれる（「状態の変化は行の追記で表す」と同じ考え方）。
- **名前空間の一意性と再利用禁止**：新しい canonical ID・alias は、予約表の全行（`active`・`retired`・`alias`）と現在の draft の ID のどれとも一致してはならない。`retired` の ID の再利用は拒否する（E1-2）。
- **改名の定義（O-3c）**：改名とは、主キーの書き換えではなく、次を**1つのトランザクションで行う**操作である（E1-3 の原子性、Studio 決定事項09 l.33「参照移行の個別手順」の具体化）。
  1. 新しい canonical ID の Spot（または地図の対象）を作る。
  2. 予約表に、新 ID の `active`、旧 ID の `retired`、`旧 ID → 新 ID` の `alias`、および旧 ID を解決先にしていた既存 alias の付け替え（上記 T2）を追記する。
  3. 旧 ID を参照している現在のデータ（イベントの会場など）を、新 ID を参照する新しい Revision へ移す。
  既存の Release・Revision は書き換えない。その時点では旧 ID が正しい ID だったため、不変の公開履歴と矛盾しない。Studio の `Spot.CanonicalId` が主キーであることも変えずに済む。
- **v1.0 での改名の扱い（O-3c R2）**：改名は Studio の画面・通常フォームには置かず（決定事項09 l.18・l.33）、レビュー済みの**管理コマンド**で行う。予約表・検査・公開時の登録は通常の公開処理として実装する。管理コマンドは最初に使う前に隔離環境で試験する。
- **射影**：bundle を作るとき、`state = alias` の行から alias ごとの最新の行を取り、その解決先がその版で公開中の spot であるものだけを `id_aliases` に含める（§3.3）。spot 以外を指す alias、`active`・`retired` の行は配信しない。台帳は追記専用なので、射影の時点を問わず版の混在は起きない。
- **資料上の旧ID の移行対応表**（例：E1-7 の部屋ID 74件、`lm_koku_shrine`）は、Studio の取り込み・map-dataset CLI・fixture 移行の入力としてだけ扱い、**参加者向けの台帳には登録しない**（O-3a）。旧 ID は bundle の `id_aliases` に現れず、受け取った場合は未掲載として扱われるため、移行漏れが表に出る。条件：(1) 最初の公開より前に、Studio の取り込みデータ（`docs/samples/reference-sample.json` を含む）・テスト・iOS の fixture を新しい ID に揃える。旧 ID のまま一度でも公開すると E1-3 規則6 の「公開した ID」になり、alias が必要になる。(2) E1-1 が ID の出典に挙げる「GitHub GeoJSON」が一般公開で旧 ID を含むかを、オーナー（技術的意思決定者）が最初の公開より前に確認する。含む場合は、その ID だけを alias として登録する。
- v1.0 の公開時点では公開済みの ID が無いため、`id_aliases` は空または少数で始まる見込みである。台帳の実装は配信 v2 の最初の到達点を妨げない。


### 5.6 経路グラフと P06 の関係（O-8 G1）

- `map.geojson` には経路グラフ（`walking_path`・`indoor_node`・`outdoor_node`）が含まれ（E1-4）、bundle 全体として端末に保存される（§6 規則3）。地図・地点・グラフが同じ版になり、版の混在が起きない。
- 経路探索は端末内で行う設計（#37）であり、オンラインのときでも計算には端末上のグラフが必要である。グラフの保存は、この設計と単一 bundle から生じる技術的な結果である。
- **グラフが保存版にあることは、オフラインでの経路再計算の保証（#83 P06）を意味しない。** オフライン時に経路機能を使えるようにするか、使える場合にどう表示するかは P06 の決定に従い、#85・#22b で実装・試験する。本契約はその振る舞いを決めない。
- 計算済みの経路を測位の喪失や通信断のあとも読めること（#85 の必須の受入条件）は P06 とは別であり、本節の制約を受けない。
- 保存版のグラフが古くなる問題（閉鎖された通路など）は、版の更新（§6）と保存版の表示（§6 規則7）で扱う。有効期限は #22 で #83 の決定待ちのまま残す。

## 6. iOS の規則（#22）

1. **全量を一度に取得する。** spot と地図を別々のリクエストで取得してはならない。
2. **検証してから保存する。** 展開後の受信バイト列の SHA-256 = `Nexus-Bundle-Sha256`、受信バイト数 = `Nexus-Bundle-Length`、payload の `bundle_version` = `Nexus-Bundle-Version`、§5.3 の不変条件。ETag は照合に使わない（§4.1.1）。いずれかが不合格なら破棄し、保存済みの版を使い続ける。
3. **原子的に切り替える。** 一時ファイルへ書き込み、全体のデコードに成功してからファイルを置換し、旧版を1世代残す。書き込み途中で異常終了した場合は、起動時に一時ファイルを破棄する。
4. **版を戻さない。** 受信した `bundle_version` が保存済みより小さい場合は、古いキャッシュ・中継の応答とみなして採用しない。Studio の復旧は新しい（大きい）版として届く。
5. **表示中の版を固定する。** 画面に表示中、または案内中の版は、利用者の操作境界（画面の再表示、案内の終了）まで差し替えない。切替の詳細なタイミングは #85 と #84 の承認範囲で決める。
6. **schema のメジャー版が未知なら**、保存済みの版を使い続け、更新が必要であることを表示する。マイナー版で追加された未知の項目は無視する。
7. 保存版の表示（`NexusSavedMetadata`）には `bundle_version`・`published_at`・最終確認日時を含める。
8. **大きさの上限を守る。** 受信はファイルへ流しながら展開後のバイト数を数え、§3.4 の硬い上限（10 MiB）を超えた時点で中断して破棄し、保存済みの版を使い続ける。`Nexus-Bundle-Length` が上限を超える応答は本体を受信せずに破棄する。
9. **ETag は解釈しない。** 受け取った `ETag` をそのまま保存して `If-None-Match` に送るだけとし、値の形式に依存しない（§4.1.1）。
10. **確認の頻度と再試行を抑える。** 更新の確認は「起動時」と「前面に戻ったときで、前回の確認から最小間隔（値は §11 O-9a で決める）が経っている場合」に限り、定期的なポーリングをしない。429・503 では `Retry-After` に従い、それ以外の失敗では指数バックオフにゆらぎ（jitter）を加えて再試行する。いずれの場合も保存済みの版を使い続ける。
11. **bundle の外から来た ID は、データ層の解決器で1段だけ解決する（O-3d U2）。**
    - 対象：bundle 以外のデータ源から来る spot の ID（イベントの会場 `SpotCode`、案内記事の関連地点など）、端末に保存した状態、将来のディープリンク。v2.0 ではイベントと案内記事は bundle に含まれず（§10）、別の版で更新されるため、改名の直後に旧 ID を参照していることがある。
    - 照合の順序：`spots[].id` との完全一致 → `id_aliases[].alias` との完全一致で1段だけ解決 → どちらも無い、または解決先が `spots` に無ければ「未掲載」。大文字小文字を区別し、正規化しない。別の地点へ置き換えない（E1-3）。
    - 照合は1つの解決器にまとめ、各画面の Store が独自に照合しない（地点詳細を作れるのは `MapContentClient` だけ、という現行の設計と同じ考え方）。
    - bundle 内の参照（spots・地図・タブ間の受け渡し）は解決器を通さない。すでに canonical ID である。
    - 端末に ID を保存する場合は、解決後の canonical ID で保存する。
    - alias で解決したかどうかを利用者に表示しない。入力された ID や解決の結果をログに残さず、送信もしない。
    - 資料上の旧 ID（E1-7 の74件など）は台帳に登録しないため（O-3a）、この解決器で解決されず「未掲載」になる。移行漏れはこれで表に出る。

## 7. 契約の版管理

- `schema_version` は SemVer に従う。
  - マイナー版：任意項目の追加など、後方互換のある変更。
  - メジャー版：項目の削除・意味の変更。エンドポイントを `/api/v3/...` に分け、旧版の配信を移行期間中は維持する。
- 契約の正本は本文書と `openapi/public.yaml`（v2 の定義を #23 で追加）とする。JSON Schema（`docs/schemas/participant-bundle-v2.schema.json`）を #23 で追加し、Studio の射影テストと iOS の fixture テストの両方で使う。

## 8. 二重 publish・二重 rollback・版の混在に対する保証

| リスク | 防ぐ仕組み |
|---|---|
| 二重 publish | 公開操作は Studio にしかない。public-api には書き込み経路が無く、`nexus_public` に INSERT 権限も無い |
| 二重 rollback | 復旧は Studio の新しい Release。配信側・iOS 側に戻す操作を持たない（§2、§6-4） |
| 地点と地図の版の混在 | 単一 bundle・単一の版（§5）、全量取得（§6-1）、原子的な切替（§6-3） |
| 射影と Release のずれ | 同じトランザクションで書く（§3.3-1） |
| 配信中の破損 | 保存時と送信時の SHA-256 照合、端末での `Nexus-Bundle-Sha256` との照合（ETag の書き換えに依存しない） |
| 巨大な応答・肥大したデータ | Studio の公開阻止（硬い上限）と警告、端末での受信中断（§3.4、§6 規則8） |
| 当日のアクセス集中・乱用 | rate limit をかけず、サーバー側で現在の版をメモリに保持して DB 負荷を版番号の確認だけに抑える。端末は確認の頻度と再試行を抑える（§4.1.2、§6 規則10）。帯域と 200 応答の件数を監視する |
| admin-api の `map_datasets` の誤用 | 本契約の出典は Studio だけ。admin-api の draft API を廃止し、admin-api に地図の入口を残さない（§8.1） |


### 8.1 admin-api の MapDataset 資産の扱い（O-7 F3）

S4-1 により地図の正本は Studio にある。admin-api に残る MapDataset 資産は次のとおり扱う。

| 資産 | 扱い | 理由 |
|---|---|---|
| `MapDatasetDraftsController`（`admin/map-datasets/drafts`：validate・作成・更新）、`MapDatasetDtos`、`packages/openapi/admin.yaml` の該当パス、コントローラーのテスト | **削除する** | admin-api を地図の入口に見せない。admin-web・web・packages に呼び出し箇所はない |
| `map_datasets` 表、`MapDataset` モデル、移行 `20260905120000_AddMapDatasets` | **残す** | この移行は PG17 baseline の移行履歴2本の1本であり、public-api・admin-api の `DatabaseReadiness` と Infra 契約B（`pg17-baseline.md` §3・§4）が「履歴2本と完全一致」を条件にしている。表を残せば契約Bと起動時検査を変えずに済む |
| `MapDatasetValidator`（admin-api 側の複製）と #77 のテスト | **Studio のテストとの突合後に削除する** | Studio に同じコードがあり二重管理になっている。Studio 28 v02 §2 の未実施事項（#77 と Studio へ移植したテストの突合）を済ませ、Studio 側で同等の検査が担保されていることを確認してから削除する |

- 残した `map_datasets` 表には誰も書かず、`nexus_public` からも読めない（契約B）。admin-api のコード上、表が残っている理由として本節を参照する。
- **表の削除は単独で行わない。** 次に移行履歴が変わる機会（本契約の `delivery` スキーマの追加、Studio による `spots.is_published` の廃止（28 v02 §5）等）に、契約Bの改訂・再検証とまとめて行う。
- 実装は本契約の PR とは**別の PR** で行う。admin.yaml を変えるため、admin-web の型を `npm run generate:api` で再生成する。本番の PG17 にはスキーマがまだなく（`pg17-baseline.md` Section 3）、`map_datasets` に本番データはない。

## 9. 責任分担と受入条件

| 担当 | 作業 | 受入条件 |
|---|---|---|
| NexusStudio | 地図の公開種別（`PublishTargetKind`）、§3.3 の射影、§5.3 の検証、目的地Featureからの `placement` の解決（§5.4）、Map Editor での目的地Featureの追加・移動（決定事項10 ME-16・ME-17）、Spot モデル・Revision・編集画面への `Kind`・`Description` の追加、追記専用の ID 予約表（公開時の ID 登録、廃止の追記、名前空間の一意性と再利用禁止の検査。§5.5）、最初の公開より前の取り込みデータ・テストの新 ID への移行（O-3a 条件1） | 公開・取り下げ・復旧のそれぞれで、正しい内容の bundle が1件増え、ポインタが進む。最初の公開時点で、取り込みデータに E1-7 の旧 ID が残っていない。種別のない Spot の公開時に、#84 の承認前は警告、承認後は公開阻止になる（O-2c）。射影の失敗で Release も残らない。JSON Schema に合格する |
| NexusInfra | `delivery` スキーマの権限（§3.2）、契約Bの改訂、隔離 PG17 での再検証、Caddy 経由の ETag・照合ヘッダー・304 の確認（O-4b） | `delivery` が Studio の `studio` スキーマと同じデータベースにある（§3.1）。`nexus_public` は `delivery` の2表だけ SELECT できる。監視に配信表の大きさが含まれる（§3.5）。`studio` スキーマ・UPDATE・DELETE・ポインタの後退は拒否される。Caddy 経由で `Nexus-Bundle-Sha256` が保持され、304 が成立する（成立しない場合は §4.2 の HEAD 追加を #23 へ求める）。**隔離環境での成功を本番適用済みとは扱わない** |
| NexusMobile #23 | `GET /api/v2/bundle`、OpenAPI、契約テスト | 200/304/404/503/500 の各テスト（HEAD を追加した場合は HEAD も同じヘッダー・Status であること）、`Nexus-Bundle-Sha256`・`Nexus-Bundle-Length` と Body の一致、バイト列が変化しないこと、public-api が圧縮しないこと、rate limit のポリシーが付いていないこと、版が変わらない間は `participant_bundles` を読み直さないこと（§4.1.2） |
| NexusMobile #22 | §6 の実装 | `SpotKind.exhibit` の削除（O-2b）。`SpotSummary.kind` を「種別なし」を表せる型にし、`kind` が null・未知の値のときに種別を表示しないこと（O-2c）。fixture で初回・304・破損・途中終了・版の後退・未知のメジャー版・照合ヘッダーの欠落・硬い上限の超過・形式の異なる ETag・429/503 の `Retry-After`・失敗時のバックオフを再現するテスト。bundle の外から来た ID の解決（完全一致・alias で1段・未掲載・大文字小文字の違い・資料上の旧 ID）の単体テスト。上限付近（8〜10 MiB）の合成 bundle での受信・デコード・保存の確認（O-4a） |
| NexusMobile（別 PR） | admin-api の draft API の削除、validator の突合後の削除（§8.1） | draft API・DTO・admin.yaml の該当パスが無く、admin-web の型が再生成されている。`map_datasets` 表と移行が残り、`DatabaseReadiness` と既存テストが通る |
| NexusMobile #21 | 旧デモ endpoint の撤去 | v2 公開後、`web/` と `packages/shared` の利用箇所を整理したうえで撤去する |

## 10. 将来の拡張（本版の範囲外）

- イベント・開催回・カテゴリの同梱：`events[].spot_id` の参照整合を同じ版で保証できる利点がある。S4-3（終日枠の時刻を配信時に同じ Release の開催時間から解決する）とあわせ、マイナー版での追加として別途判断する。
- 差分配信：bundle の大きさが問題になるまで採用しない。

## 11. 未決事項（承認前に決める）

| ID | 論点 | 影響 | 決定先 |
|---|---|---|---|
| O-1 | spot の位置（`placement`）を地図の公開版のどこに持つか | **決定（2026-10-20 利用者判断）：案1 目的地Feature方式**（§5.4）。比較した案は §12 | — |
| O-1a | 目的地種別の名称・分け方 | **決定（2026-10-21、E1-4 改訂1 R-2）：`room` / `landmark` の2種**。`room_type`（決定事項26 の `cl` / `cr` / `wc` / `rm`）は ID 構造の分類で、`kind` の出典にしない（O-2 K1） | E1-4 改訂1 |
| O-1b | 目的地Featureの geometry | E1-4 改訂1 で Point のみを提案。部屋の外形は `room` を参照する別種別で後から追加する（同 §7） | E1-4 改訂1 |
| O-1c | 表示名の正本 | E1-4 改訂1 で `room` / `landmark` に `name` を持たせず Spot 公開版を正本とする案を提案（同 §6） | E1-4 改訂1、Studio |
| O-1d | `access_node_id` を必須にする時期 | **決定（2026-10-21、E1-4 改訂1 R-5）：任意とし、欠落は警告。主要6経路の目的地だけ #79 で確認する**。`building` / `formal_entrance` の到達ノードは同 §4.3 の規則で求める | E1-4 改訂1、#37、#79 |
| O-2 | spot の種別と説明文の出典 | **決定（2026-10-20 利用者判断）：K1＋D1**。種別・説明文とも Studio の Spot 属性として追加し、Spot 単独で公開する（§5.2）。比較した案は §12 | — |
| O-2a | 種別の候補の集合 | **決定（2026-10-21 利用者判断）：K-a 初期の候補を `classroom` / `facility` / `service` の3つとし、割り当ての指針を §5.2 に置く**。製品仕様としての確定は #84（Figma `2622:818` の承認）と #83 P12 の決定による。トイレを独立させる `restroom` の追加は #84 の検討事項として残す。比較した案は §12 | #84、#83 P12 |
| O-2b | `exhibit`（展示）を地点の種別から外すか | **決定（2026-10-21 利用者判断）：E1 外す**。展示はイベント側（`eventID`・`SpotEventContext`）で地点に関連付け、iOS の `SpotKind.exhibit` は #22 の PR で削除する。検索結果でイベントを区別する「結果の型」は #27 で設計する（§5.2）。比較した案は §12 | #22、#27 |
| O-2c | 公開時に種別を必須にするか | **決定（2026-10-21 利用者判断）：C4** #84 で候補が承認されるまでは警告、承認後は Studio の公開前検証で公開を止める。**契約は null 可のまま維持する**（当初の「必須化した時点で null を許可しない版へ上げる」は撤回）。iOS は null・未知の値で種別を表示しない（§5.2）。比較した案は §12 | Studio、#22、#84 |
| O-2d | 説明文の作成者・確認者・更新頻度 | **決定（2026-10-21 利用者判断）：D-1** 供給元・確認者・公開者・更新頻度は #49 で決める。#49 が決まるまで Studio は説明文を公開せず（運用上の取り決め）、`description` は null で配信する。開発チームは代わりの文を書かない（§5.2）。比較した案は §12 | #49 |
| O-3 | ID alias の正本の置き場所 | **決定（2026-10-20 利用者判断）：A1 Studio の追記専用台帳**（§5.5）。比較した案は §12 | — |
| O-3a | 資料上の旧ID（E1-7 の部屋ID 74件、`lm_koku_shrine`）を参加者向けの alias として登録するか | **決定（2026-10-21 利用者判断）：B 移行の対応表に留め、台帳に登録しない**（§5.5）。条件：(1) 最初の公開より前に、Studio の取り込みデータ（`docs/samples/reference-sample.json` を含む）・テスト・iOS の fixture を新しい ID に揃える。旧 ID のまま一度でも公開すると E1-3 規則6 の「公開した ID」になり、alias が必要になる。(2) E1-1 が ID の出典に挙げる「GitHub GeoJSON」が一般公開で旧 ID を含むかを、オーナー（技術的意思決定者）が最初の公開より前に確認する。含む場合は、その ID だけを alias として登録する。当初「旧ID が名前空間を永久に占有する」を理由に挙げたが、旧 ID の形式は新しい規則と形が異なり衝突の実害は小さいため、主な理由は公開記録がないことと移行漏れを隠さないことである。比較した案は §12 | オーナー（条件2）、Studio・iOS（条件1） |
| O-3b | 台帳の対象範囲 | **決定（2026-10-21 利用者判断）：S2 一度でも公開された ID と alias を記録する追記専用の ID 予約表**（§5.5）。draft の ID は登録せず検証時に照合する。bundle に配信するのは spot を指す alias だけ。比較した案は §12 | — |
| O-3c | 改名処理の扱いと alias の解決先の持ち方 | **決定（2026-10-21 利用者判断）：R2＋T2**。改名は「新しい ID の発行・旧 ID の廃止・参照の移行」を1トランザクションで行う操作と定義し、v1.0 では Studio の画面に置かずレビュー済みの管理コマンドで行う。alias の解決先は追記で更新し、alias ごとに最新の行を有効とする（§5.5）。比較した案は §12 | — |
| O-3d | iOS での alias の使い道 | **決定（2026-10-21 利用者判断）：U2** bundle の外から来た ID（イベントの会場・案内記事の関連地点・保存した状態・将来のディープリンク）だけを、データ層の解決器で1段だけ解決する。入力 ID や解決結果はログに残さず送信しない（§6 規則11）。DEBUG ビルドの端末内表示などの例外は設けない。比較した案は §12 | — |
| O-4 | bundle の大きさの上限 | **決定（2026-10-20 利用者判断）：S3 硬い上限 10 MiB＋警告 2 MiB**（§3.4）、および照合専用ヘッダー `Nexus-Bundle-Sha256` の追加（§4.1.1）。比較した案は §12 | — |
| O-4a | 警告の閾値と大きさの見込みが推定であること | **決定（2026-10-21 利用者判断）：A4** 絶対値 2 MiB（仮）と前版比 1.5倍（仮）のどちらかで警告する（公開は止めない）。経路グラフを含む最初の実データで実測して両方を見直す。上限付近の合成 bundle で iOS の負荷を #22 の試験で先に確かめる（§3.4）。比較した案は §12 | #23、Studio、#22 |
| O-4b | Caddy v2.11.4 の `encode` が ETag・`Nexus-Bundle-Sha256`・`If-None-Match` をどう扱うかを隔離環境で確認する（ETag の書き換え、304 の成立、独自ヘッダーが保持されること） | §4.1.1 の前提の検証。照合ヘッダーにより完全性は ETag に依存しないが、304 が成立しないと毎回全量を送ることになる | NexusInfra（隔離検証）、#23 |
| O-5 | manifest エンドポイントが必要か | **決定（2026-10-21 利用者判断）：M1 条件付き GET だけで始める**。O-4b で 304 が成立しない場合に限り `HEAD /api/v2/bundle` を追加する（§4.2）。
  - **古い bundle は v1.0 では削除しない（O-6 R1）**。見直しの条件と将来の削除の制約を §3.5 に定める。
  - **Studio の `studio` スキーマと配信用の `delivery` スキーマは同じ PostgreSQL データベースに置く**（§3.1）。比較した案は §12 | — |
| O-6 | 古い bundle の保持期間と削除方法 | **決定（2026-10-21 利用者判断）：R1 v1.0 では削除しない**。見直しの条件（合計 1 GiB または 500 件）と将来の削除の制約を §3.5 に定めた。あわせて、`delivery` を `studio` と同じデータベースに置く前提を §3.1 に明記した。比較した案は §12 | — |
| O-7 | admin-api の `map_datasets` と draft API の扱い | **決定（2026-10-21 利用者判断）：F3 API を廃止し、表と移行は残す**。表の削除は次に移行履歴が変わる機会にまとめる。validator は Studio のテストとの突合後に削除する。実装は本 PR と別の PR で行う（§8.1）。比較した案は §12 | — |
| O-8 | 経路グラフを bundle に含めることと P06（オフライン経路再計算）の関係 | **決定（2026-10-21 利用者判断）：G1 グラフを含めて保存し、保存は P06 の保証を意味しないと明記する**（§5.6）。P06 が決まるまでのオフライン時の経路機能の振る舞いは本契約で決めず、#83 の P06 の決定待ちとする。比較した案は §12 | — |
| O-8a | #83 は Closed だが P05/P06 の採否記録が見当たらない。#22 の「グラフ保存は #83 の決定を待つ」に対し、本契約は「技術的には保存する。保証の有無は P06」と整理した。P06 の決定先と記録方法（#83 の Reopen を含む）を決める | #85・#22b のオフライン時の振る舞いと試験 | 技術的意思決定者、#83 |
| O-9 | 構内ネットワークの NAT（来場者が1つの外向き IP を共有する可能性）と rate limit。**訂正**：当初「public-api は IP ごとに 60 回/分」と記載したが、develop のコードでは rate limit は属性を付けたエンドポイントだけにかかり、public-api では `POST /api/logs`（60 回/分）と `/api/logs/batch`（12 回/分）だけが対象で、公開 GET は対象外である（`RateLimitingExtensions.cs`、`LogsController.cs:40,68`、`docs/rate-limiting.md`） | **決定（2026-10-21 利用者判断）：L1** bundle の GET には rate limit をかけず、サーバー側キャッシュと端末側の規則で備える（§4.1.2、§6 規則10）。L2（IP ごとの緩い上限）は乱用を観測したときの予備策として記録する。比較した案は §12 | — |
| O-9a | 更新確認の最小間隔の値 | §6 規則10 の値 | #22b |
| O-9b | ログ送信（`POST /api/logs`・`/batch`）と構内 NAT。IP ごとの上限により、来場者が多いと 429 になりうる（`docs/rate-limiting.md` の既知の制約）。本契約の範囲外とし、別 Issue で扱う | ログ送信の上限・単位、iOS のログ送信の有無と再送方針 | 別 Issue（E8-4 の続き） |

## 12. 却下した選択肢

| 案 | 却下理由 |
|---|---|
| 案a：public-api が `studio` スキーマを直接読む | Studio の表構造の変更が public-api に直接波及する。`nexus_public` に `studio` の読み取り権限が必要になり、契約Bの「将来追加表の SELECT 拒否」の考え方から大きく外れる |
| 案c：静的ファイルの配信 | 参加者向け配信を public-api が担う決定（28 v02 §2・§4）から外れる。公開と配信の整合を DB トランザクションで保証できない |
| spot・地図を別々のエンドポイント・別々の版で配信 | 端末で版が混在する。整合を取るにはクライアント側で複雑な調停が必要になる |
| `payload` を `jsonb` で保存 | 保存時に正規化され、ハッシュと配信バイト列が一致しなくなる |
| O-1 案2：配置レジストリ（`nexus.spot_placements[]` に spot_id → 点・階・ノードを書く） | 建物・正式入口を目的地にする場合、既存 Feature とレジストリで位置が二重定義になる。地物ではないため Map Editor で特別扱いが必要になり、部屋形状への拡張もしにくい |
| O-1 案3：Spot 公開版に座標・階を持たせる | S4-2（位置は地図と一緒に公開）の撤回が必要。地図版と Spot 版をまたいだ参照になり、検証が版をまたぐ |
| O-1 案4：既存 Feature（building / formal_entrance / indoor_node）だけで解決 | 部屋を `indoor_node` として作ることになり、経路グラフと目的地が混ざる。E1-4 v1 は `node_kind: destination` でノードを目的地とする余地を残しているが、ノードには部屋の種別・所属を表す属性がない。E1-3 もノードを目的地とする場合は基準データ上で明示することを求めている（当初の記載「E1-3 の注意に反する」は言い過ぎだったため訂正）。ただし building / formal_entrance に限った利用は案1の部分集合として §5.4 で許容する |
| O-2d D-2：契約で作成・確認・公開の役割を定める | 技術契約に承認されていない組織上の前提を固定することになり、組織が変わるたびに契約の改訂が要る。Studio は1人で公開できるため、書いても強制できない |
| O-2d D-3：v1.0 では説明文を使わない（常に null）と契約で決める | #49 の結果として選べる選択肢であり、契約で先に決める必要がない |
| O-2d D-4：正式な原稿が届くまで開発チームが暫定の文を書く | #84 の「正式情報と誤認する仮表示を残さない」に反する |
| O-2c C1：必須にし、契約も null 不可の版へ上げる | 候補が #84 の承認待ちのうちに入力を強いると、承認後の付け直しが起きうる。iOS は未知の値のためにどのみち「種別なし」を扱うので、契約を null 不可にする利点が小さい |
| O-2c C2：任意（検査なし） | 種別のない Spot が残りやすく、#27 の「種別で区別」に使えない |
| O-2c C3：警告のみ（恒久） | 警告を見落とせば種別のない Spot が残る。候補の承認後は公開を止めて品質を保つ方がよい |
| O-2b E2：iOS の `SpotKind.exhibit` を残し、契約では使わない | 契約と iOS の型が食い違ったまま残り、使い始めると契約にない値を iOS が作ることになる |
| O-2b E3：契約の候補に `exhibit` を加える | §5.2（展示はイベントの性質）と O-2a を改める必要がある。教室で展示をする場合などに地点の種別と展示が混ざる。常設展示エリアが必要になれば後からマイナー版で追加できる |
| O-2a K-b：初期から4種（3種＋`restroom`） | トイレの独立は来場者に有用な可能性が高いが、探すのカテゴリチップの追加（#84 の画面設計）と一体の判断であり、値の追加はマイナー版で後からできる。#84 の検討事項として残した |
| O-2a K-c：細分化（5〜6種） | iOS の型・チップ・テストの作り直しが必要。「教室」と「実習室」などの境界が来場者にも Studio の担当者にも分かりにくい。一度出した値を減らすとメジャー版になる |
| O-2 K2：目的地Featureの型（`cl` / `wc` / `rm` 等）から種別を導出 | `rm` に実習室と事務室が混在し分類として粗い。受付・救護などのサービスを導出できない。表示上の分類が ID の命名規則に縛られる。決定事項26 は mobile 側へ未昇格 |
| O-2 K3：種別を持たない | #27 の受入条件（同名の結果を種別・建物・階で区別する）と衝突する |
| O-2 K4：Studio のイベント用カテゴリを流用 | 学科・体験分類と施設分類で意味が違い、イベント用カテゴリの変更が地点に波及する |
| O-2 D2：説明文を v2.0 では配信しない | 任意項目の追加は後方互換なので先送りの利点が小さく、地点詳細が名称だけになる |
| O-2 D3：旧 `public.spots.Description` を流用 | 中身はデモの seed 値で ID も canonical でない。Studio の取り込みも引き継いでおらず、廃止予定の経路（28 v02 §5）に依存する |
| O-2 D4：説明を案内記事へのリンクで代替 | 別のコンテンツ系統で供給元（#49）が未決。長文の説明は #49 側で別に判断する |
| O-3d U1：iOS は alias を使わない | 改名の直後、別のデータ源（イベント・案内記事）の更新が遅れる間、その地点が「未掲載」になる |
| O-3d U3：経路ごとに alias を使うか決める | 照合の条件分岐が各経路に散らばり、経路が増えるたびに判断が要る |
| O-3c R1：改名を Studio の画面・API で提供する | 画面・確認・権限・試験が増え、決定事項09 の「通常フォームから除外」に反する。Figma にも画面がない。v1.0 時点で公開済み ID の改名はまれと見込める |
| O-3c R3：v1.0 では改名を禁止する | 公開後に ID の誤りが見つかった場合、取り下げて作り直すしかなく、旧 ID の参照が切れる |
| O-3c T1：alias の解決先を安定した内部キー（GUID 等）で持つ | 内部キーが追従するのは主キーをその場で書き換える改名だけで、「新しい ID の対象を作る」改名では新しい行に別のキーが付くため追従しない。Studio のモデル変更も必要 |
| O-3c T3：改名時に既存 alias の解決先を書き換える | 予約表の追記専用（§5.5）に反し、履歴が失われる |
| O-3c T4：連鎖を許し、解決時にたどる | E1-3 が alias の連鎖を禁じており、bundle の解決は1段のみ（§5.2） |
| O-3b S1：台帳を spot の alias だけにし、spot 以外の再利用禁止は地図の過去の版の走査で検査する | E1-2 規則6（spot 以外の改名の記録）を構造的に記録する場所がない。再利用禁止の根拠が過去の版の JSON 走査という暗黙のものになる |
| O-3b S3：参加者向けの spot alias 台帳と、spot 以外の改名・廃止を記録する内部の表を分ける | 表と検査が2系統になり、E1-3 の「単一の予約済み名前空間」を2つの表の組み合わせで引くことになる。S2 と比べて利点がない |
| O-3a A：資料上の旧ID 75件を全件 alias に登録（Studio 決定事項26 の案） | 公開記録がなく守るべき外部参照がない。旧 ID が alias で黙って解決され、fixture や取り込みデータの移行漏れに気付けなくなる。alias は削除できないため不要な行が永久に残る |
| O-3a C：外部参照の痕跡があるものだけ登録 | 現時点で痕跡は見つかっていない。O-3a 条件2 の確認で痕跡が見つかった場合の扱いとして B に組み込んだ |
| O-3 A2：Spot の公開版（Revision）に旧ID を持たせる | 過去の版へ復旧すると alias が消え、E1-3「削除しない」に反する。Spot 以外の ID の改名を扱えない |
| O-3 A3：地図の公開版（GeoJSON `nexus.id_aliases`）に持たせる | 地図を過去の版へ戻すと alias が消える。Spot だけの改名にも地図の公開が必要になる。draft や他版との衝突を検査できない |
| O-3 A4：nexus-mobile の DB（admin-api）に置く（E1-3 の元の想定） | S4-1 により spot・地図の正本は Studio にあり、名前空間の検査が DB をまたぐ。admin-api は縮小方向 |
| O-3 A5：リポジトリ上の静的な対応表を正本にする | 実行時の機構ではないため、改名との原子性を保証できない。資料上の旧ID の移行入力としてだけ使う（§5.5） |
| O-4a A1：絶対値の閾値だけを置き、実測後に見直す | 見込みがずれていると閾値が甘すぎたり厳しすぎたりし、急な増加を見つけにくい |
| O-4a A2：実測まで警告を出さない | 硬い上限の 10 MiB に達するまで肥大に気付けない |
| O-4a A3：前版比だけで警告する | 直前の版がない最初の公開で働かない |
| O-4 S1：bundle に上限を設けない | spots・alias を含めた全体の大きさが決まらず、iOS の負荷を見積もれない |
| O-4 S2：硬い上限だけ | 肥大が硬い上限に達するまで気付けない |
| O-4 S4：小さい硬い上限（例 2 MiB） | 地図の上限 8 MiB より小さく、データの増加で正当な公開が止まる |
| O-4 S5：分割配信 | 単一 bundle の決定に反し、端末で版が混在しうる |
| O-5 M2：manifest エンドポイント（`GET /api/v2/bundle/manifest`） | ヘッダーと重複する JSON スキーマが増える。ETag に依存しない確認は HEAD（M3）で同じヘッダーのまま実現できる |
| O-5 M3 を最初から実装 | 304 が成立すれば不要で、更新時のリクエストが2回に増える。O-4b の結果を見てから追加する |
| O-6 R2：件数で保持（直近 N 件） | 削除用の保守 role・手順・テストが必要で、v1.0 の保存量の見込みに対して費用が見合わない。見直しの条件に達したときの候補として残す |
| O-6 R3：期間で保持 | R2 と同じ理由。見直しの条件に達したときの候補として残す |
| O-6 R4：現在の版だけを保持（上書き） | 追記専用の設計が崩れ、配信していたバイト列を確認できなくなる |
| O-6 R5：`payload` だけを消しメタデータを残す | UPDATE が必要で `payload NOT NULL` も崩れる。中身は Studio からの再構成に頼るが、同じバイト列になる保証がない |
| O-7 F1：admin-api の draft API を現状維持 | admin-api が地図の入口に見え、正本の誤認・誤投入の余地が残る。validator の二重管理も残る |
| O-7 F2：draft API を 410 Gone で凍結 | 使わないコード経路と validator の二重管理が残り、F3 より利点がない |
| O-9 L2：IP ごとに緩い上限（例 120〜300 回/分）を最初から付ける | 構内の外向き IP の構成が未確認で、正当な来場者を止めない安全な値を決められない。乱用を観測したときの予備策として残す（§4.1.2） |
| O-9 L3：本体を返す 200 だけを数える | 応答を見て数える独自の limiter が必要。更新直後に一斉取得すると共有 IP で上限に達しうる |
| O-9 L4：端末ごとの匿名 ID で制限 | 端末の識別子を新たに導入することになり、個人を特定しない粒度の方針（CLAUDE.md）に反する。ID は偽装もできる |
| O-9 L5：edge（Caddy）で制限 | Caddy の標準機能に rate limit はなく、プラグイン（新しい依存）が必要。共有 IP の問題も L2 と同じ |
| O-8 G2：グラフを bundle から外す（別エンドポイントまたはサーバー側で経路計算） | グラフと地図の版が分かれて混在しうる。サーバー側計算は #37（端末内エンジン）の前提を変え、public-api に計算 API が増える |
| O-8 G3：P06 が承認されたときだけグラフを含める | 承認前は別経路でグラフを取得することになり G2 と同じ問題が生じる。bundle の中身が2通りになる |
| O-8 G4：グラフを含めるがグラフ部分だけ保存しない | bundle の一部を捨てて保存すると、保存版を SHA-256 で再検証できない（§6 規則2） |
| O-7 F4：表も新しい移行で削除する（単独で実施） | 移行履歴が3本になり、Infra 契約B §3・§4 の改訂、`DatabaseReadiness` の変更、隔離 PG17 での再検証が必要になる。表を消すだけの効果に見合わないため、次に移行履歴が変わる機会（`delivery` スキーマの追加、`spots.is_published` の廃止等）にまとめる |
| 完全性の照合に ETag を使う（当初の草案） | edge の圧縮で ETag が書き換えられると照合が成り立たない。照合専用ヘッダーに分離した |
