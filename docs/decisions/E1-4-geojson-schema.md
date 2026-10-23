# E1-4: GeoJSON スキーマを定義する

- 移行元ID: E1-4 / 区分: E1
- 依存: E1-2（`docs/decisions/E1-2-hierarchical-ids.md`）
- 判断日: 2026-09-03
- 判断者: リポジトリオーナー（技術的意思決定者）
- 状態: 採用
- 改訂: [改訂1 目的地Featureの追加](E1-4-r1-destination-features.md)（2026-10-21 採用、`schema_version` 2.0.0）を本文へ反映した。判断の経緯と却下した選択肢は改訂1を参照する。map-dataset CLI（`tools/map-dataset`、E1-6）も 2.0.0 を既定とする

## 採用方針

MapDataset の地理データ payload は、[RFC 7946](https://www.rfc-editor.org/rfc/rfc7946) に従う単一の `FeatureCollection` とする。Nexus 固有の構造は、GeoJSON の型名を拡張せず、Feature の `properties.feature_type` と FeatureCollection の外部メンバー `nexus` で表す。

機械可読な正本は [`docs/schemas/map-dataset-geojson-v2.schema.json`](../schemas/map-dataset-geojson-v2.schema.json) とし、JSON Schema Draft 2020-12 で記述する。具体例は [`docs/schemas/examples/map-dataset-geojson-v2.example.json`](../schemas/examples/map-dataset-geojson-v2.example.json) に置く。1.0.0 の [`map-dataset-geojson-v1.schema.json`](../schemas/map-dataset-geojson-v1.schema.json) と例は記録として残し、reader は 2.x だけを受け付ける（改訂1 §3）。

```text
MapDataset.payload
└─ FeatureCollection
   ├─ nexus.schema_version
   ├─ nexus.floors[]
   └─ features[]
      ├─ building          / Polygon
      ├─ formal_entrance   / Point
      ├─ walking_path      / LineString
      ├─ indoor_node       / Point
      ├─ outdoor_node      / Point
      ├─ room              / Point（改訂1）
      └─ landmark          / Point（改訂1）
```

Issue 本文の4対象に加え、E1-2 で正式入口の `outside_node_id` の参照先として確定済みの屋外ノードを `outdoor_node` として含める。これにより、published payload 内の参照先を別ファイルへ逃がさず、E2-2 validator が未定義 ID を検出できる。

## FeatureCollection の契約

| メンバー | 必須 | 規則 |
|---|---|---|
| `type` | 必須 | 常に `FeatureCollection` |
| `nexus.schema_version` | 必須 | 本契約では `2.0.0`。MapDataset のデータ版とは別の、payload 契約の版 |
| `nexus.floors` | 必須 | フロアの非空間レジストリ。空配列は許可する |
| `features` | 必須 | 本文書で許可した Feature の配列。空配列は draft では許可する |
| `bbox` | 任意 | RFC 7946 の2次元 `[west, south, east, north]`。4要素固定 |

`nexus.floors` の各要素は `id`、`building_id` を必須とし、表示用の `name` を任意とする。フロア自体を `geometry: null` の Feature にはしない。フロアは地物ではなく、屋内ノードと正式入口が参照する論理階層だからである。

MapDataset エンティティ側の `version`、`status`、`checksum`、`publishedAt` は E2-1 の管理メタデータであり、GeoJSON payload に重複して保持しない。`nexus.schema_version` はデータ改訂番号ではなく、読み取り側が payload の互換性を判定するための値である。

## 共通 Feature 契約

すべての Feature は次を満たす。

1. `type` は `Feature` とする。
2. `id` は文字列の canonical ID とし、同じ値を `properties.id` へ複製しない。
3. `geometry` は Feature 種別ごとに固定し、`null`、`GeometryCollection`、想定外の複数形 geometry を許可しない。
4. `properties.feature_type` を discriminator とする。
5. `id` は payload 全体で Feature 種別をまたいで一意とする。
6. 不明なプロパティは誤記として拒否する。契約追加時は `schema_version` の互換性を判断してスキーマを更新する。
7. 表示名は `name` に保持し、ID や geometry から生成しない。正式名称未確定の地物では省略できる。ただし `room` / `landmark` は `name` を持たず、表示名の正本は Spot 公開版の `name` とする（改訂1 §6）。

## Feature 種別

### 建物ポリゴン

| 項目 | 値・規則 |
|---|---|
| `properties.feature_type` | `building` |
| `geometry.type` | `Polygon` |
| `id` | E1-1 で確定した14棟の `building_id` |
| 任意プロパティ | `name`、`access_node_id` |

- `name` は、ほかの地点が所在する建物の名前（例「教室棟・2F」）に使う。建物を目的地として表示するときの名前は Spot 公開版の `name` とし、両者の不一致は Studio の公開前検証で警告する（改訂1 §6）。
- `access_node_id` は建物を目的地にしたときの到達ノードで、同じ `building_id` の `indoor_node`（`node_kind: destination`）を指す。無ければ `is_primary = true` の正式入口の `outside_node_id` を使う。屋外直結の正式入口を登録しない建物（`ptb`・`aptr`）はこの項目で指定する。どのノードにするかは現地確認の後に決め、推測で指定しない（改訂1 §4.4）。

中庭などの穴は Polygon の内環で表す。v1.0 の建物を複数の独立面へ分割して `MultiPolygon` にすることは許可しない。現地形状上どうしても分離面が必要になった場合は、同一建物として扱う根拠とクライアント影響を確認し、スキーマ改訂を先に行う。

### 正式入口ポイント

| プロパティ | 必須 | 規則 |
|---|---|---|
| `feature_type` | 必須 | `formal_entrance` |
| `building_id` | 必須 | Feature `id` の建物部分と一致する登録済み建物 |
| `floor_id` | 必須 | `building_id` 配下の登録済みフロア |
| `outside_node_id` | 必須 | payload 内の `outdoor_node` |
| `inside_node_id` | 必須 | 同じ `floor_id` の `indoor_node` |
| `is_primary` | 必須 | 当該建物の代表入口なら `true` |
| `accessibility` | 必須 | `accessible` / `not_accessible` / `unknown` |
| `name` | 任意 | 表示名。IDには反映しない |
| `opening_hours` | 任意 | 表示用の文字列。構造化営業時間や臨時閉鎖は別契約で扱う |

geometry は出入口の閾値位置を示す `Point` とする。入口 Feature 自体が屋外・屋内グラフの接続関係を保持するため、同じ接続を重複した `walking_path` として作らない。

### 歩行経路

`walking_path` はノード間の1辺を表し、LineString の座標列は `from_node_id` から `to_node_id` の順に並べる。

| プロパティ | 必須 | 規則 |
|---|---|---|
| `feature_type` | 必須 | `walking_path` |
| `scope` | 必須 | `campus` または `indoor` |
| `from_node_id` | 必須 | 始点ノード ID |
| `to_node_id` | 必須 | 終点ノード ID。始点と同じ値は不可 |
| `path_kind` | 必須 | `walkway` / `corridor` / `ramp` / `stairs` |
| `bidirectional` | 必須 | 双方向なら `true`。`false` の場合は座標順方向だけ通行可 |
| `accessibility` | 必須 | `accessible` / `not_accessible` / `unknown` |
| `distance_m` | 必須 | 0 より大きい実測または変換時算出距離 |
| `estimated_seconds` | 必須 | 0 より大きい標準徒歩所要秒数 |
| `building_id` | 屋内のみ | 経路が属する建物 |
| `floor_id` | 屋内のみ | 経路が属するフロア |

屋外辺の ID は `campus_e_{seq:03}`、屋内辺は `{floor_id}_e_{seq:03}` とする。連番、不変性、再利用禁止は E1-2 のノード規則と同じとする。

- `scope=campus` の両端は `outdoor_node` とし、`building_id` / `floor_id` を持たない。
- `scope=indoor` の両端は同じ `floor_id` の `indoor_node` とし、`building_id` / `floor_id` を必須とする。
- 階をまたぐ接続やエレベーター乗車は `walking_path` に混在させず、E5 の屋内遷移契約で扱う。
- `distance_m` と `estimated_seconds` は経路探索の重みと表示の入力であり、クライアントごとに geometry から再計算しない。

### 屋内ノード

| プロパティ | 必須 | 規則 |
|---|---|---|
| `feature_type` | 必須 | `indoor_node` |
| `building_id` | 必須 | 登録済み建物 |
| `floor_id` | 必須 | `building_id` 配下の登録済みフロア |
| `node_kind` | 必須 | `junction` / `destination` / `transition` |
| `name` | 任意 | 利用者向け名称。単なる折れ点では省略する |

`id` は E1-2 の `{floor_id}_n_{seq:03}` に従う。`destination` は `room` の到達ノード、または `building` の `access_node_id` が指す到達ノード（2.0.0 で意味を変更。改訂1 §5）、`transition` は階段等の階層遷移への接続点、`junction` は経路計算専用の分岐・折れ点を表す。

### 屋外ノード

| プロパティ | 必須 | 規則 |
|---|---|---|
| `feature_type` | 必須 | `outdoor_node` |
| `scope` | 必須 | 常に `campus` |
| `node_kind` | 必須 | `junction` / `destination` / `entrance_approach` |
| `name` | 任意 | 利用者向け名称 |

`id` は E1-2 の `campus_n_{seq:03}` に従う。正式入口へ接続する外側ノードには `entrance_approach` を使う。`destination` は `landmark` の到達ノードを表す（2.0.0 で意味を変更。改訂1 §5）。

ノード ID を spot の ID にしない。spot は目的地Feature（`building`・`formal_entrance`・`room`・`landmark`）からだけ解決する（E2-5 §5.4）。

### 部屋（改訂1）

| 項目 | 必須 | 規則 |
|---|---|---|
| `id` | 必須 | `{floor_id}_{room_type}_{seq:03}`（[E1-7](E1-7-room-canonical-ids.md)）。例 `mb_2f_cl_001` |
| `geometry.type` | 必須 | `Point`。部屋の代表点 |
| `properties.feature_type` | 必須 | `room` |
| `properties.building_id` | 必須 | 登録済み建物。`id` の建物部分と一致 |
| `properties.floor_id` | 必須 | `building_id` 配下の登録済みフロア。`id` の `{floor_id}` 部分と一致 |
| `properties.room_type` | 必須 | `cl`（教室）/ `cr`（廊下）/ `wc`（トイレ）/ `rm`（その他の室）。`id` の `{room_type}` 部分と一致 |
| `properties.access_node_id` | 任意 | 到達ノード。同じ `floor_id` の `indoor_node` で、`node_kind` が `destination` |

- `room_type` は ID 構造のための分類であり、参加者向けの種別（E2-5 §5.2 の `kind`）の出典にしない。
- 代表点は利用者に示す位置であり、経路の到達点は `access_node_id` が示す。
- 部屋の外形が必要になった場合は、`room` の geometry を変えず、`room_id` で参照する別の種別を minor 版で追加する（改訂1 §7）。

### ランドマーク（改訂1）

| 項目 | 必須 | 規則 |
|---|---|---|
| `id` | 必須 | `campus_lm_{seq:03}`。例 `campus_lm_001`。表示名から生成しない |
| `geometry.type` | 必須 | `Point` |
| `properties.feature_type` | 必須 | `landmark` |
| `properties.scope` | 必須 | 常に `campus` |
| `properties.access_node_id` | 任意 | 到達ノード。`outdoor_node` で、`node_kind` が `destination` |

`landmark` は `building_id` / `floor_id` を持たない。屋内の目印は `room` または将来の別種別で扱う。

### 到達ノードの欠落

`access_node_id` はスキーマ上任意とし、欠落は publish validator の警告とする（公開は止めない）。到達ノードの無い目的地は「位置は分かるが経路は対象外」として扱う。主要6経路（#33）の目的地は例外とし、到達ノードがそろっていることを #79 で確認する（改訂1 §8）。

## 座標と GeoJSON 準拠

- v1.0 の geometry は2次元に限定し、position は `[longitude, latitude]` の2要素固定とする。
- longitude / latitude は RFC 7946 に従い WGS 84（OGC CRS84）の10進度とする。旧 GeoJSON の `crs` メンバーは使用しない。
- altitude の第3要素は許可しない。階は `floor_id` で表し、高度が必要になった場合は geometry と `bbox` を同じ次元で扱う次版の契約を先に定義する。
- FeatureCollection、Feature、geometry の `bbox` は `[west, south, east, north]` の4要素固定とする。全 position が2次元のため、対象 geometry と `bbox` の次元は常に一致する。
- Polygon の外環は反時計回り、内環は時計回りとし、各環の先頭・末尾位置を一致させる。
- indoor の測量元ローカル座標をそのまま GeoJSON geometry に格納しない。E1-5 は、アンカーと変換規則、および必要なら変換元座標を保持する別の入力契約を決める。
- 過剰な座標精度を避けるが、丸め桁数と許容誤差は E1-5 で確定する。

これにより GeoJSON 対応ライブラリが geometry を標準どおり解釈でき、Nexus 固有の座標系を暗黙に推測する必要がない。

## JSON Schema と validator の責務

JSON Schema は次を検証する。

- 必須メンバー、型、列挙値、ID の字句形式
- Feature 種別と geometry 型の組み合わせ
- 座標配列が2次元であること、`bbox` が4要素であること、longitude / latitude の数値範囲
- 屋内・屋外経路で許されるプロパティとノード ID 形式
- 未定義プロパティ

JSON Schema 単体では、配列をまたぐ参照整合や幾何学的妥当性を完全には表現できない。E2-2 validator は追加で次を検証する。

1. Feature `id` と floor `id` の全体一意性、および E1-3 の alias 予約名前空間との衝突。
2. `building_id`、`floor_id`、ノード参照の存在と親子整合。
3. 正式入口の内外ノード種別、および入口 geometry と接続ノードの距離許容値。
4. 経路端点と LineString の先頭・末尾位置の一致、始点と終点の相違。
5. Polygon 環の閉鎖、向き、自己交差、空形状、キャンパス許容範囲。
6. 孤立ノード、到達不能ノード、同一ノード間の重複辺。
7. `distance_m` / `estimated_seconds` の有限値と、geometry または変換元データに対する許容誤差。
8. `room.id` の `{floor_id}`・`{room_type}` 部分が `properties.floor_id`・`properties.room_type` と一致すること（改訂1 §12）。
9. `access_node_id` の参照先が存在し、`room` では同じ `floor_id` の `indoor_node`、`landmark` では `outdoor_node`、`building` では同じ `building_id` の `indoor_node` であり、いずれも `node_kind: destination` であること。
10. どの目的地Featureからも参照されない `node_kind: destination` のノード、正式入口も `access_node_id` も持たない `building`、`room` / `landmark` の `access_node_id` の欠落を警告とすること。
11. `room` / `landmark` の `id` が E2-5 §5.5 の ID 予約表と現在の draft の ID に衝突せず、`retired` の ID を再利用しないこと。

draft 保存では空の `floors` / `features` を許可するが、publish validator は利用対象に応じた必要データと参照閉包を要求する。

## バージョニングと互換性

- `nexus.schema_version` は SemVer とし、本契約の初版を `1.0.0` とする。改訂1 は列挙値 `node_kind: destination` の意味を変えたため `2.0.0` とした（改訂1 §3）。
- 任意プロパティの追加など、既存 reader が無視して安全な変更は minor とする。ただし本スキーマは未知プロパティを拒否するため、reader と schema の更新は同時に行う。
- 必須プロパティ、列挙値の意味、geometry 型、ID 規則の変更は major とする。
- 誤記修正や制約を変えない説明更新は patch とする。
- publisher は対応していない major version を publish せず、client は対応していない major version を読み込まない。

配信時の media type は `application/geo+json` とする。HTTP API の DTO が envelope を追加する場合も、payload 自体はこの FeatureCollection を保持する。

## 採用理由

- RFC 7946 の標準 geometry を維持し、QGIS、変換ツール、API、iOS の間で独自 geometry 変換を減らせる。
- `Feature.id` を canonical ID の単一の格納先にするため、`properties.id` との不一致が発生しない。
- `feature_type` と厳格なプロパティ集合により、同じ Point である入口とノードを機械的に区別できる。
- floor レジストリを payload 内に持つため、屋内 Feature の親参照を同じ payload だけで検証できる。
- 屋外ノードを含めることで、正式入口と屋外グラフの参照閉包を保てる。
- `distance_m` と `estimated_seconds` を辺に持たせることで、端末内探索と表示が同じ確定値を利用できる。
- machine-readable schema を判断記録と同時に置くことで、E1-6、E2-1、E2-2 が同じ契約を実装できる。

## 却下した選択肢

- **独自 JSON を採用して geometry だけ GeoJSON 風にする**: 標準ツールがそのまま扱えず、座標順や geometry 意味の独自解釈が増えるため却下。
- **FeatureCollection を種別ごとの複数ファイルに分割する**: 参照先不在の中間状態が生じ、checksum、publish、rollback の原子性が損なわれるため却下。
- **GeoJSON の `type` を `Building` や `Entrance` に拡張する**: RFC 7946 が定義する GeoJSON 型の拡張に当たり、標準 reader と互換にならないため却下。
- **種別を geometry 型だけで推測する**: 入口とノードはいずれも Point で区別できず、将来の Point 地物追加にも耐えないため却下。
- **canonical ID を `properties.id` のみに置く**: GeoJSON 標準の Feature `id` と二重管理になるか、標準 reader が識別子を利用できなくなるため却下。
- **屋内ローカル座標を GeoJSON の `coordinates` に格納して `crs` で識別する**: RFC 7946 では `crs` が廃止されており、一般的な reader が WGS 84 と誤解するため却下。
- **v1.0 で高度を任意の第3要素として許可する**: 2次元・3次元 geometry の混在と `bbox` の次元不一致を招き、現行の地図・経路要件にも不要なため却下。高度が必要になった時点で payload 全体の次元を明示する次版を定義する。
- **`additionalProperties: true` で任意の属性を許す**: 誤記を検出できず、publisher と client で意味の異なる属性が蓄積するため却下。
- **正式入口と内外ノードを同じ Point / ID に統合する**: E1-2 で分離したライフサイクルと参照関係を失うため却下。
- **距離と所要時間を各 client が geometry から算出する**: 実装・丸め・速度仮定により経路選択と表示が一致しなくなるため却下。

## 後続Issueが前提にできる事項

- E1-5 は canonical GeoJSON geometry を WGS 84 で出力し、屋内ローカル座標からの変換規則と許容誤差を決める。
- E1-6 は本 JSON Schema に適合する単一 FeatureCollection を決定的に生成する。
- E1-7 / E4-1 は Feature `id`、`feature_type`、geometry、参照、経路コストを本契約に従って作る。
- E2-1 の `payload` は本 FeatureCollection を保持し、MapDataset の管理メタデータを payload と分離する。
- E2-2 は JSON Schema 検証に加え、本書の参照整合・幾何・グラフ検証を行う。
- API と iOS は `nexus.schema_version` の major version を確認してから読み込む。

## 後続実装の受入条件

- 正常例が JSON として読み込め、本 JSON Schema に適合する。
- geometry と `feature_type` の不一致、未知プロパティ、無効な ID、範囲外座標が schema 検証で拒否される。
- 重複 ID、未定義参照、親子不一致、未閉鎖 Polygon、孤立・到達不能ノードが E2-2 validator で拒否される。
- 同じ入力と ID 対応表から、Feature 配列順を含めて決定的な payload と checksum を再生成できる。
- published payload の Feature 参照が同じ payload 内で閉じている。

## 本Issueのスコープ外

- 14棟の実 geometry、正式入口、フロア、経路、ノードの具体データ
- 屋内ローカル座標のアンカー、変換式、精度、丸め規則
- Excel / QGIS の入力列と変換スクリプト
- JSON Schema validator、参照整合 validator、publish 処理の実装
- MapDataset DB エンティティ、API DTO、OpenAPI、iOS 型の実装
- 階段・エレベーターによる階層間遷移と、建物間の連絡路のデータ契約（#42 で設計し、改訂2で定める）
- 駐車場、道路等の追加 Feature 種別（部屋とランドマークは改訂1で追加した）

これらは後続 Issue で扱うが、GeoJSON envelope、Feature 識別、基本プロパティ、geometry 型、参照の向き、schema version の扱いについて追加の前提確認は不要とする。
