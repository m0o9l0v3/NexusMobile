# E2-5: 参加者向け公開データ配信契約 v2（草案）

- 移行元ID: E2-5 / 区分: E2 / 対応Issue: [#23](https://github.com/m0o9l0v3/NexusMobile/issues/23)（関連: #21, #22, #85）
- 状態: **草案（未承認）**。本文書の採用は、NexusStudio・NexusInfra 側の対応記録とあわせて技術的意思決定者が承認する。
- 起案日: 2026-10-20
- 承認済みの前提（2026-10-20 利用者判断）:
  - **DB境界は案b**：Studio が公開結果を配信用の表へ射影し、public-api はその表だけを読む。
  - **単一bundle**：地点と地図を1つのドキュメント・1つの版として配信する。
  - **地点の位置の正本は目的地Feature（O-1 案1）**：spot の位置は、`spot.id` と同じ canonical ID を持つ地図 Feature から解決する（§5.4）。
  - **種別と説明文は Spot の属性（O-2 K1＋D1）**：参加者向けの種別（閉じた集合）と任意の説明文を Studio の Spot 公開版に追加し、Spot 単独で公開する（S4-2、Studio 決定事項09）。
  - **ID alias の正本は Studio の追記専用台帳（O-3 A1）**：E1-3 の `spot_id_aliases` を Studio に実装し、bundle には解決先が公開中の alias だけを射影する（§5.5）。
- 上位の決定: NexusStudio 決定事項28 v02 S4-1（地図の公開・復旧は Studio に一本化）、S4-2（Spot 属性と位置の公開単位の分離）、NexusStudio 決定事項10 §1（Spot のピン・階は地図版に含む）、E1-3（`Spot.Code == SpotDto.Id == canonical ID`、spot は MapDataset の対象を同じ ID で参照する read model）、E1-4（GeoJSON v1）、E1-5（WGS 84）。
- 前提となる別改訂: 目的地Featureの追加には E1-4 の改訂（GeoJSON payload 契約 1.1.0）が必要である。本文書は 1.1.0 の存在を前提にするが、その内容の正本は E1-4 改訂側とする。

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
- 保持期間・古い bundle の削除は運用判断とし、本契約では決めない（§11 O-6）。

### 3.3 射影の規則（Studio の責任）

1. 射影は Release を書くのと**同じトランザクション**で行う。途中で失敗した場合は Release も bundle も残らない（Studio の既存の公開保証に従う）。
2. bundle の内容は、その時点の `Publication` が `published` を指す全 spot と、公開中の地図1件から**全量で**組み立てる。差分配信はしない。
3. 組み立てた payload は §5 の不変条件を満たさなければならない。満たさない場合は公開そのものを失敗させる（Studio の公開前検証 `CandidateValidator` に追加する）。
4. 全ての spot が取り下げられた場合も、bundle を削除せず、空の `spots` を持つ新しい版を作る。
5. `id_aliases` は alias 台帳（§5.5）から、解決先が当該版で公開中の spot である行だけを含める。

## 4. HTTP API（public-api）

### 4.1 `GET /api/v2/bundle`

現在公開中の bundle を返す。認証なし・読み取り専用。既存の rate limiting を適用する。

**リクエストヘッダー**

| ヘッダー | 用途 |
|---|---|
| `If-None-Match` | 端末が保持している版の ETag |

**200 OK**

| 項目 | 値 |
|---|---|
| Body | `participant_bundles.payload` のバイト列そのもの |
| `Content-Type` | `application/json; charset=utf-8` |
| `ETag` | `"sha256-<sha256>"`（strong） |
| `Nexus-Bundle-Version` | `bundle_version`（10進） |
| `Nexus-Bundle-Schema` | `schema_version` |
| `Cache-Control` | `no-cache`（保存してよいが、使う前に再検証が必要） |

- `ETag` は**圧縮前の**バイト列のハッシュとする。応答圧縮を有効にする場合も、iOS はデコード後のバイト列で検証する。
- public-api は送信前に `payload` の SHA-256 を再計算し、`sha256` 列と一致しなければ 500 を返す（§4.3）。中身の妥当性（§5）を public-api は再検証しない。それは Studio の責任である。

**304 Not Modified**：`If-None-Match` が現在の ETag と一致した場合。Body なし。`ETag` と `Nexus-Bundle-Version` を付ける。

### 4.2 `GET /api/v2/bundle/manifest`（任意）

Body を持たない軽量な確認用。`{ "bundle_version", "release_id", "schema_version", "sha256", "byte_length", "published_at" }` を返す。iOS が条件付き GET だけで足りる場合は実装しなくてよい（§11 O-5）。

### 4.3 エラー（RFC 9457 Problem Details）

| 状況 | Status | `type` |
|---|---|---|
| まだ一度も bundle が公開されていない | 404 | `urn:nexus:problem:bundle-not-published` |
| DB に接続できない・タイムアウト | 503（`Retry-After` 付き） | `urn:nexus:problem:bundle-unavailable` |
| `sha256` の不一致（保存データの破損） | 500 | `urn:nexus:problem:bundle-integrity` |
| rate limit 超過 | 429 | 既存の挙動 |

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
    "geojson": { "type": "FeatureCollection", "nexus": { "schema_version": "1.1.0", "floors": [] }, "features": [] }
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
| `kind` | string \| null | 必須（null可） | Spot 公開版 `Kind`（**Studio に追加が必要**） | 参加者向けの種別。閉じた集合で、値の候補は §11 O-2a で決める。null は「種別未設定」。公開時に必須とするかは O-2c で決め、必須化した時点で null を許可しない版へ上げる |
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
- 展示（exhibit）は地点ではなくイベントの性質として扱い、地点と展示の対応はイベント側の情報で表す。iOS の `SpotKind.exhibit` の扱いは O-2b で決める。
- 候補の集合への値の追加はマイナー版とする。iOS は同じメジャー版の中で未知の `kind` を受け取っても bundle を拒否せず、種別を表示しない（他の地点の表示を止めない）。

`description` は Spot 単独で公開する属性（S4-2）であり、地図の公開版とは独立して更新される。単一 bundle のため、どちらが更新されても新しい版として全量が配信される。

**`id_aliases[]`**（必須。空配列可）：E1-3 の規則6（旧ID を alias として残す）に対応する。出典は Studio の alias 台帳（§5.5）。

| 項目 | 型 | 規則 |
|---|---|---|
| `alias` | string | 旧ID。大文字小文字を区別する完全一致 |
| `canonical_id` | string | 解決先の現行 canonical ID。`spots[].id` に存在する |

`alias` → `canonical_id` の解決は1段のみで、連鎖させない。台帳の全件ではなく、**解決先がこの版で公開中の spot である alias だけ**を含む。iOS がこの表をどの入力（保存した目的地、将来のディープリンク等）の解決に使うかは §11 O-3d で決める。

**`map`**（object | null）：null は「公開中の地図がない」。

| 項目 | 型 | 規則 |
|---|---|---|
| `dataset_version` | integer | Studio `MapDataset.Version` |
| `dataset_sha256` | string | Studio `MapDataset.Checksum`（payload 文字列の SHA-256） |
| `geojson` | object | E1-4 の GeoJSON v1。Studio の publish validator に合格したもの |

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
| 部屋・施設・ランドマーク用の種別 | **E1-4 改訂（1.1.0）で追加** | Point（Polygon はマイナー版で追加を検討） | 屋内の部屋・施設、屋外のランドマーク |

- 新しい種別の名称・分け方（`room` / `landmark` の2種か、`destination` 1種＋`destination_type` 属性か）は E1-4 改訂で決める（§11 O-1a）。本文書の例の `room` は仮の名称である。
- `walking_path`・`indoor_node`・`outdoor_node` は経路グラフの要素であり、目的地種別に含めない。経路計算用ノードを目的地として直接公開しない（E1-3）。
- 1つの canonical ID に目的地Featureは1件だけ存在する（E1-4 規則5の種別横断一意による）。
- 目的地Featureの表示名の正本は Spot 公開版の `name` とし、新しい目的地種別の Feature には `name` を持たせない案を E1-4 改訂で検討する（§11 O-1c）。`building` Feature の `name` は現行どおり建物名として使う。
- spot として公開されていない目的地Featureが地図にあってもよい（例：Spot 未登録の部屋）。逆に、目的地Featureがない spot は `placement: null` で配信する。

段階的な導入:

- E1-4 改訂前でも、目的地を `building` / `formal_entrance` に限れば、スキーマ v1.0.0 のまま本方式で位置を解決できる。これは別方式ではなく、本方式の部分集合として扱う。
- 屋内の部屋・施設の点は、どの方式でも #36（フロアごとのアンカーと floor-local 座標）が揃うまで公開できない。本方式の採用はこのデータ不足を解消しない。

### 5.5 ID alias 台帳（O-3 A1）

alias の正本は、Studio に実装する**追記専用**の台帳とする。E1-3「alias 方針」の設計（`spot_id_aliases`）を、置き場所だけ nexus-mobile の DB から Studio へ移して適用する（S4-1 により spot・地図の正本が Studio にあるため）。

- **版管理しない**。行の追加だけを許し、変更・削除をしない（E1-3「外部参照に使われた可能性がある alias は削除しない」）。Spot や地図を過去の版へ復旧しても（S4-5）、alias は消えない。
- **最低限の項目**：`alias_code`（旧ID）、`spot_id`（解決先の Spot。Studio では `Spot.CanonicalId` が主キーのため、改名で主キーが変わる場合の参照方法は O-3c とあわせて決める）、`created_at`、登録の根拠（改名操作の ID または取り込み元）。
- **名前空間の一意性**：登録時に、Studio が持つ全ての canonical ID（Spot、MapDataset の draft・公開版を問わない全 Feature とフロア）および既存の alias との衝突を検査する。新しい canonical ID の登録時も、全 alias との衝突を検査する（E1-3）。
- **改名との原子性**：改名処理は、alias の登録と ID の切り替えを同じトランザクションで行う（E1-3）。
- **射影**：bundle を作るとき、解決先がその版で公開中の spot である alias だけを `id_aliases` に含める（§3.3）。台帳は追記専用なので、射影の時点を問わず版の混在は起きない。
- **資料上の旧ID の移行対応表**（例：Studio 決定事項26 の部屋ID 74件）は、Studio の取り込みや map-dataset CLI の入力として扱う。参加者向けの台帳へ登録するかは O-3a で決める。
- v1.0 の公開時点では公開済みの ID が無いため、`id_aliases` は空または少数で始まる見込みである。台帳の実装は配信 v2 の最初の到達点を妨げない。

## 6. iOS の規則（#22）

1. **全量を一度に取得する。** spot と地図を別々のリクエストで取得してはならない。
2. **検証してから保存する。** 受信バイト列の SHA-256 = `ETag`、payload の `bundle_version` = ヘッダー、§5.3 の不変条件。いずれかが不合格なら破棄し、保存済みの版を使い続ける。
3. **原子的に切り替える。** 一時ファイルへ書き込み、全体のデコードに成功してからファイルを置換し、旧版を1世代残す。書き込み途中で異常終了した場合は、起動時に一時ファイルを破棄する。
4. **版を戻さない。** 受信した `bundle_version` が保存済みより小さい場合は、古いキャッシュ・中継の応答とみなして採用しない。Studio の復旧は新しい（大きい）版として届く。
5. **表示中の版を固定する。** 画面に表示中、または案内中の版は、利用者の操作境界（画面の再表示、案内の終了）まで差し替えない。切替の詳細なタイミングは #85 と #84 の承認範囲で決める。
6. **schema のメジャー版が未知なら**、保存済みの版を使い続け、更新が必要であることを表示する。マイナー版で追加された未知の項目は無視する。
7. 保存版の表示（`NexusSavedMetadata`）には `bundle_version`・`published_at`・最終確認日時を含める。

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
| 配信中の破損 | 保存時と送信時の SHA-256 照合、端末での照合 |
| admin-api の `map_datasets` の誤用 | 本契約の出典は Studio だけ。admin-api の `MapDatasetDraftsController` と `map_datasets` の扱いは別途決める（§11 O-7） |

## 9. 責任分担と受入条件

| 担当 | 作業 | 受入条件 |
|---|---|---|
| NexusStudio | 地図の公開種別（`PublishTargetKind`）、§3.3 の射影、§5.3 の検証、目的地Featureからの `placement` の解決（§5.4）、Map Editor での目的地Featureの追加・移動（決定事項10 ME-16・ME-17）、Spot モデル・Revision・編集画面への `Kind`・`Description` の追加、追記専用の alias 台帳と名前空間の一意性検査（§5.5） | 公開・取り下げ・復旧のそれぞれで、正しい内容の bundle が1件増え、ポインタが進む。射影の失敗で Release も残らない。JSON Schema に合格する |
| NexusInfra | `delivery` スキーマの権限（§3.2）、契約Bの改訂、隔離 PG17 での再検証 | `nexus_public` は `delivery` の2表だけ SELECT できる。`studio` スキーマ・UPDATE・DELETE・ポインタの後退は拒否される。**隔離環境での成功を本番適用済みとは扱わない** |
| NexusMobile #23 | `GET /api/v2/bundle`、OpenAPI、契約テスト | 200/304/404/503/500 の各テスト、ETag と Body の一致、バイト列が変化しないこと |
| NexusMobile #22 | §6 の実装 | fixture で初回・304・破損・途中終了・版の後退・未知のメジャー版を再現するテスト |
| NexusMobile #21 | 旧デモ endpoint の撤去 | v2 公開後、`web/` と `packages/shared` の利用箇所を整理したうえで撤去する |

## 10. 将来の拡張（本版の範囲外）

- イベント・開催回・カテゴリの同梱：`events[].spot_id` の参照整合を同じ版で保証できる利点がある。S4-3（終日枠の時刻を配信時に同じ Release の開催時間から解決する）とあわせ、マイナー版での追加として別途判断する。
- 差分配信：bundle の大きさが問題になるまで採用しない。

## 11. 未決事項（承認前に決める）

| ID | 論点 | 影響 | 決定先 |
|---|---|---|---|
| O-1 | spot の位置（`placement`）を地図の公開版のどこに持つか | **決定（2026-10-20 利用者判断）：案1 目的地Feature方式**（§5.4）。比較した案は §12 | — |
| O-1a | 目的地種別の名称・分け方（`room` / `landmark` の2種か、`destination`＋`destination_type` か）。Studio 決定事項26 の部屋 ID 対応表の `type` 列（`wc`・`rm` 等）を O-2 の種別の出典にできるかもあわせて検討する | E1-4 1.1.0 の内容 | E1-4 改訂 |
| O-1b | 目的地Featureの geometry を Point のみで始めるか（Polygon はマイナー版で追加） | 部屋形状の表示時期 | E1-4 改訂 |
| O-1c | 表示名の正本。目的地種別の Feature に `name` を持たせず Spot 公開版を正本にするか | 表示名の二重管理 | E1-4 改訂、Studio |
| O-1d | `access_node_id` を必須にする時期。経路グラフ（#32・#39）の公開前は任意とし、経路を公開する条件として必須化するか | #37 の到達先、validator の公開阻止条件 | #37、#39、Studio validator |
| O-2 | spot の種別と説明文の出典 | **決定（2026-10-20 利用者判断）：K1＋D1**。種別・説明文とも Studio の Spot 属性として追加し、Spot 単独で公開する（§5.2）。比較した案は §12 | — |
| O-2a | 種別の候補の集合。iOS の現行案（教室・施設・サービス）で始めるか | `kind` の値、探すのカテゴリチップ | #84（Figma `2622:818` の承認）、#83 P12（検索対象） |
| O-2b | `exhibit`（展示）を地点の種別から外すか | iOS `SpotKind` の変更 | #84、#27 |
| O-2c | 公開時に種別を必須にするか（種別のない Spot を公開阻止するか） | `kind` の null 可否、Studio の公開前検証 | Studio |
| O-2d | 説明文の作成者・確認者・更新頻度 | `description` の中身。未決の間は null で配信する | #49 |
| O-3 | ID alias の正本の置き場所 | **決定（2026-10-20 利用者判断）：A1 Studio の追記専用台帳**（§5.5）。比較した案は §12 | — |
| O-3a | 資料上の旧ID（Studio 決定事項26 の部屋ID 74件、全件 `alias_required = yes`）を参加者向けの alias として登録するか、移行対応表に留めるか。E1-3 規則6 の趣旨は公開済みID の保護であり、74件に公開の記録は見当たらない。登録すると旧ID は名前空間を永久に占有する | 台帳の初期内容。決定事項26 の採用案との整合 | Studio 決定事項26、E1-3 |
| O-3b | 台帳の対象を Spot の ID に限るか、建物・フロア・ノード等の改名にも使う ID 予約表とするか | 台帳の項目（`spot_id` か汎用の参照か） | E1-3、Studio |
| O-3c | 改名処理を v1.0 に含めるか。Studio の `Spot.CanonicalId` は主キーで、決定事項09 は保存後の変更を通常の編集で許していない | 含めない場合は「表と検査のみ実装し、登録は取り込み時だけ」の段階にできる | Studio |
| O-3d | iOS での alias の使い道。bundle の外から来た ID（保存した目的地、将来のディープリンク等）を1段だけ解決し、解決先が bundle に無ければ「未掲載」とするか | §6 への規則の追加 | #22、#85 |
| O-4 | bundle の大きさの上限 | Studio の MapDataset validator は payload 8 MiB を上限にしている。bundle の上限（例: 16 MiB）と、iOS のメモリ・通信量の想定 | #23、#22 |
| O-5 | manifest エンドポイント（§4.2）が必要か | 条件付き GET だけで足りるなら実装しない | #22 |
| O-6 | 古い bundle の保持期間と削除方法 | 表の肥大化。削除してもポインタの指す版は消さない | Infra 運用 |
| O-7 | admin-api の `map_datasets` と draft API の扱い（廃止・凍結） | 出典の誤認 | NexusMobile |
| O-8 | 経路グラフ（walking_path・node）を bundle に含めることと P06（オフライン経路再計算）の関係 | 含めても再計算の保証にはならないことを明記するか | #83 |

## 12. 却下した選択肢

| 案 | 却下理由 |
|---|---|
| 案a：public-api が `studio` スキーマを直接読む | Studio の表構造の変更が public-api に直接波及する。`nexus_public` に `studio` の読み取り権限が必要になり、契約Bの「将来追加表の SELECT 拒否」の考え方から大きく外れる |
| 案c：静的ファイルの配信 | 参加者向け配信を public-api が担う決定（28 v02 §2・§4）から外れる。公開と配信の整合を DB トランザクションで保証できない |
| spot・地図を別々のエンドポイント・別々の版で配信 | 端末で版が混在する。整合を取るにはクライアント側で複雑な調停が必要になる |
| `payload` を `jsonb` で保存 | 保存時に正規化され、ハッシュと配信バイト列が一致しなくなる |
| O-1 案2：配置レジストリ（`nexus.spot_placements[]` に spot_id → 点・階・ノードを書く） | 建物・正式入口を目的地にする場合、既存 Feature とレジストリで位置が二重定義になる。地物ではないため Map Editor で特別扱いが必要になり、部屋形状への拡張もしにくい |
| O-1 案3：Spot 公開版に座標・階を持たせる | S4-2（位置は地図と一緒に公開）の撤回が必要。地図版と Spot 版をまたいだ参照になり、検証が版をまたぐ |
| O-1 案4：既存 Feature（building / formal_entrance / indoor_node）だけで解決 | 部屋を `indoor_node` として作ることになり、経路グラフと目的地が混ざる（E1-3 の注意に反する）。ただし building / formal_entrance に限った利用は案1の部分集合として §5.4 で許容する |
| O-2 K2：目的地Featureの型（`cl` / `wc` / `rm` 等）から種別を導出 | `rm` に実習室と事務室が混在し分類として粗い。受付・救護などのサービスを導出できない。表示上の分類が ID の命名規則に縛られる。決定事項26 は mobile 側へ未昇格 |
| O-2 K3：種別を持たない | #27 の受入条件（同名の結果を種別・建物・階で区別する）と衝突する |
| O-2 K4：Studio のイベント用カテゴリを流用 | 学科・体験分類と施設分類で意味が違い、イベント用カテゴリの変更が地点に波及する |
| O-2 D2：説明文を v2.0 では配信しない | 任意項目の追加は後方互換なので先送りの利点が小さく、地点詳細が名称だけになる |
| O-2 D3：旧 `public.spots.Description` を流用 | 中身はデモの seed 値で ID も canonical でない。Studio の取り込みも引き継いでおらず、廃止予定の経路（28 v02 §5）に依存する |
| O-2 D4：説明を案内記事へのリンクで代替 | 別のコンテンツ系統で供給元（#49）が未決。長文の説明は #49 側で別に判断する |
| O-3 A2：Spot の公開版（Revision）に旧ID を持たせる | 過去の版へ復旧すると alias が消え、E1-3「削除しない」に反する。Spot 以外の ID の改名を扱えない |
| O-3 A3：地図の公開版（GeoJSON `nexus.id_aliases`）に持たせる | 地図を過去の版へ戻すと alias が消える。Spot だけの改名にも地図の公開が必要になる。draft や他版との衝突を検査できない |
| O-3 A4：nexus-mobile の DB（admin-api）に置く（E1-3 の元の想定） | S4-1 により spot・地図の正本は Studio にあり、名前空間の検査が DB をまたぐ。admin-api は縮小方向 |
| O-3 A5：リポジトリ上の静的な対応表を正本にする | 実行時の機構ではないため、改名との原子性を保証できない。資料上の旧ID の移行入力としてだけ使う（§5.5） |
