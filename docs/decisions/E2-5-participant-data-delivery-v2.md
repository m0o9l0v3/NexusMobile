# E2-5: 参加者向け公開データ配信契約 v2（草案）

- 移行元ID: E2-5 / 区分: E2 / 対応Issue: [#23](https://github.com/m0o9l0v3/NexusMobile/issues/23)（関連: #21, #22, #85）
- 状態: **草案（未承認）**。本文書の採用は、NexusStudio・NexusInfra 側の対応記録とあわせて技術的意思決定者が承認する。
- 起案日: 2026-10-20
- 承認済みの前提（2026-10-20 利用者判断）:
  - **DB境界は案b**：Studio が公開結果を配信用の表へ射影し、public-api はその表だけを読む。
  - **単一bundle**：地点と地図を1つのドキュメント・1つの版として配信する。
- 上位の決定: NexusStudio 決定事項28 v02 S4-1（地図の公開・復旧は Studio に一本化）、S4-2（Spot 属性と位置の公開単位の分離）、E1-3（`Spot.Code == SpotDto.Id == canonical ID`）、E1-4（GeoJSON v1）、E1-5（WGS 84）。

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
      "search_aliases": ["2A", "にーえー"],
      "utilization": "available",
      "placement": {
        "building_id": "mb",
        "floor_id": "mb_2f",
        "point": [139.000000, 35.000000]
      }
    }
  ],
  "id_aliases": [
    { "alias": "mb_f2_cr_2a", "canonical_id": "mb_2f_rm_001" }
  ],
  "map": {
    "dataset_version": 7,
    "dataset_sha256": "…64桁…",
    "geojson": { "type": "FeatureCollection", "nexus": { "schema_version": "1.0.0", "floors": [] }, "features": [] }
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
| `search_aliases` | string[] | 必須（空可） | Spot 公開版 `Aliases` | 名称検索用の別名。**ID の alias（`id_aliases`）とは別物** |
| `utilization` | string | 必須 | Spot 公開版 `Utilization` | `available` / `noNewSelection`。`withdrawn` の spot は bundle に含めない |
| `placement` | object \| null | 必須（null可） | **地図の公開版**（S4-2） | null は「位置が未公開」。推測で埋めない |
| `placement.building_id` | string | 必須 | 地図 | `map.geojson` 内の `building` Feature の `id` |
| `placement.floor_id` | string \| null | 必須（null可） | 地図 | `map.geojson.nexus.floors[].id`。屋外・階未確定は null |
| `placement.point` | [lon, lat] \| null | 必須（null可） | 地図 | WGS 84、小数6桁（E1-5） |

建物名・階名の表示は、`placement` から `map.geojson` の `building.properties.name` と `nexus.floors[].name` を参照して得る。spot 側に表示名を重複して持たない（Studio の `BuildingName` / `FloorName` 文字列は S4-2 により配信の正本にしない）。

**`id_aliases[]`**（必須。空配列可）：E1-3 の規則6（旧ID を alias として残す）に対応する。`alias` → `canonical_id` の解決は1段のみで、連鎖させない。

**`map`**（object | null）：null は「公開中の地図がない」。

| 項目 | 型 | 規則 |
|---|---|---|
| `dataset_version` | integer | Studio `MapDataset.Version` |
| `dataset_sha256` | string | Studio `MapDataset.Checksum`（payload 文字列の SHA-256） |
| `geojson` | object | E1-4 の GeoJSON v1。Studio の publish validator に合格したもの |

### 5.3 不変条件（Studio が射影時に保証し、iOS が受信時に検査する）

1. `spots[].id` は一意。比較は大文字小文字を区別する。
2. `id_aliases[].alias` はどの `spots[].id` とも一致しない。`canonical_id` は `spots[].id` に存在する。取り下げた spot を指す alias は含めない。
3. `placement` が null でない場合、`map` は null でなく、`building_id` と `floor_id` が `map.geojson` に存在する。`floor_id` の所属建物は `building_id` と一致する。
4. bundle に含まれるのは、Studio の `Publication` が `published` を指す spot だけである。未公開・取り下げ済みの spot と ID は含めない。
5. 地図に含まれない ID・未知の ID を、受付など別の地点へ置き換えない（iOS の `unknownSpot` 表示を維持する）。
6. `bundle_version` は過去に配信したどの版よりも大きい。

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
| NexusStudio | 地図の公開種別（`PublishTargetKind`）、§3.3 の射影、§5.3 の検証 | 公開・取り下げ・復旧のそれぞれで、正しい内容の bundle が1件増え、ポインタが進む。射影の失敗で Release も残らない。JSON Schema に合格する |
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
| O-1 | spot の位置（`placement`）を地図の公開版のどこに持つか。GeoJSON v1 には部屋・地点の Feature 種別がない（E1-4 は building / formal_entrance / walking_path / indoor_node / outdoor_node のみ） | `placement` を埋められない。v1.1 で地点 Feature を追加するか、別の対応表を地図と同時に公開するか | E1-4 改訂、Studio Map Data |
| O-2 | spot の種別（iOS `SpotKind`: 教室・施設・サービス・展示）と説明文。Studio の Spot 公開版は `Name / Aliases / Utilization` だけで、種別と説明を持たない（S4-2 は「説明」を Spot 単独公開としているが未実装） | 本版では項目を定義していない。追加する場合は Studio のモデル変更が必要 | Studio、#83 |
| O-3 | ID alias の正本の置き場所。mobile・Studio のどちらにも `spot_id_aliases` の実装がない | `id_aliases` を作れない。本版では空配列で開始できる | Studio、E1-3 |
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
