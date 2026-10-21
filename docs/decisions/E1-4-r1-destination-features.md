# E1-4 改訂1: 目的地Featureの追加（草案）

- 改訂対象: [E1-4 GeoJSON スキーマ](E1-4-geojson-schema.md)（状態: 採用）と [`docs/schemas/map-dataset-geojson-v1.schema.json`](../schemas/map-dataset-geojson-v1.schema.json)
- 状態: **草案（未承認）**。判断事項 R-1〜R-8 は 2026-10-21 に利用者がすべて判断済み（§9）。改訂全体の承認は R-3 の前提（決定事項26 の E1-7 昇格）の後に行う。承認されるまで E1-4 本文と JSON Schema は変更しない。承認後、本書の内容を E1-4 へ反映し、スキーマを別の PR で更新する。
- 起案日: 2026-10-21
- 起点の決定: [E2-5 配信契約 v2](E2-5-participant-data-delivery-v2.md) O-1 案1（目的地Feature方式、2026-10-20 利用者判断）。spot の位置・建物・階・到達ノードの正本を、`spot.id` と同じ canonical ID を持つ地図 Feature とする。
- 関連: E1-2（階層 ID）、E1-3（canonical ID・alias）、E1-5（座標系）、NexusStudio 決定事項26（部屋 canonical ID 規則、委任に基づく採用案）、NexusStudio 決定事項10（MapEditor）、#36・#39（屋内データ）、#37（端末内経路探索）、#79（主要6経路の受け入れ試験）

## 1. 目的

E2-5 の目的地Feature方式を実現するため、GeoJSON payload に部屋とランドマークを表す Feature 種別を追加し、目的地と経路グラフの関係（到達ノード）を定める。E2-5 §11 の O-1a〜O-1d に対する提案を本書で示す。

E1-4 の「本Issueのスコープ外」に挙げられていた「部屋、駐車場、道路、ランドマーク等の追加 Feature 種別」のうち、**部屋とランドマーク**を本改訂の対象とする。駐車場・道路は対象外とする。

## 2. 改訂の要約

| # | 変更 | E2-5 の未決事項 | 互換性 |
|---|---|---|---|
| 1 | Feature 種別 `room`（屋内・Point）を追加 | O-1a | 追加 |
| 2 | Feature 種別 `landmark`（屋外・Point）を追加 | O-1a | 追加 |
| 3 | `room` / `landmark` に任意の `access_node_id`（到達ノード）を追加 | O-1d | 追加 |
| 4 | `indoor_node` / `outdoor_node` の `node_kind: destination` の意味を「スポットとして公開可能なノード」から「目的地Featureの到達ノード」に改める | O-1 案1 の帰結 | **意味の変更** |
| 5 | `room` / `landmark` は `name` を持たない。表示名の正本は Spot 公開版とする | O-1c | 方針 |
| 6 | `room` / `landmark` の geometry は Point に限る。部屋の外形は将来、別種別で追加する | O-1b | 方針 |
| 7 | `nexus.schema_version` を **2.0.0** とする | — | §3 |
| 8 | `building` に任意の `access_node_id`（建物の到達ノード）を追加 | O-10 | 追加 |

## 3. 版番号（決定：2.0.0、R-1）

E1-4「バージョニングと互換性」は、**列挙値の意味の変更を major** と定めている。変更4（`node_kind: destination` の意味の変更）はこれに当たるため、本改訂は **2.0.0** とする。

- 1.0.0 の payload が公開された記録はない。Studio に地図の公開種別はまだなく（`PublishTargetKind` は event / occurrence / categories / spot）、admin-api の draft API は publish を持たないまま削除された（PR #102）。major にすることの実害は、reader の更新が必要になることに限られる。
- 本スキーマは未知のプロパティ・種別を拒否するため、種別の追加（変更1〜3）だけでも reader と schema の同時更新が必要であり、minor と major で reader の作業量は変わらない。
- スキーマファイルは `map-dataset-geojson-v2.schema.json` として新設し、v1 のファイルは記録として残す。reader（Studio の validator、map-dataset CLI、iOS）は 2.x だけを受け付ける。
- 代替案（1.1.0 とし、意味の変更を「1.0.0 の公開実績がないため例外」と扱う）は、E1-4 自身の版管理規則に例外を作るため採らない（§10）。

## 4. 追加する Feature 種別

### 4.1 `room`（部屋）

屋内の部屋・諸室を表す。

| 項目 | 必須 | 規則 |
|---|---|---|
| `id` | 必須 | `{floor_id}_{room_type}_{seq:03}`（NexusStudio 決定事項26 §2）。例 `mb_2f_cl_001` |
| `geometry.type` | 必須 | `Point`。部屋の代表点（WGS 84、E1-5 の変換規則と丸めに従う） |
| `properties.feature_type` | 必須 | `room` |
| `properties.building_id` | 必須 | 登録済み建物。`id` の建物部分と一致 |
| `properties.floor_id` | 必須 | `building_id` 配下の登録済みフロア。`id` の `{floor_id}` 部分と一致 |
| `properties.room_type` | 必須 | `cl`（教室）/ `cr`（廊下）/ `wc`（トイレ）/ `rm`（その他の室）。決定事項26 §2.1 の閉じた集合。`id` の `{room_type}` 部分と一致 |
| `properties.access_node_id` | 任意 | 到達ノード。同じ `floor_id` の `indoor_node` で、`node_kind` が `destination`（§5） |

- `room_type` は **ID 構造のための分類**であり、参加者向けの種別（E2-5 §5.2 の `kind`）ではない。`kind` を `room_type` から導出しない（E2-5 O-2 K1）。
- 部屋 ID 規則は Studio 決定事項26（状態：委任に基づく採用案）に依存する。本改訂の承認前に、同決定を nexus-mobile の `E1-7` として昇格させる（§9 R-3、判断済み）。昇格案は [E1-7 草案](E1-7-room-canonical-ids.md)（未承認）。
- 代表点は、部屋の中で利用者に示す位置であり、経路の到達点とは限らない。経路の到達点は `access_node_id` が示す（E1-4「表示用の位置と経路の到着点を混同しない」、Studio 決定事項09）。

### 4.2 `landmark`（ランドマーク）

屋外の目印・施設（建物でも入口でもないもの）を表す。例：航空神社。

| 項目 | 必須 | 規則 |
|---|---|---|
| `id` | 必須 | `campus_lm_{seq:03}`（§9 R-4）。例 `campus_lm_001`。E1-2 の屋外ノード `campus_n_{seq:03}` と同じくキャンパス全体で連番を採り、表示名から生成しない（E1-3）。連番の不変性・再利用禁止は E1-2 のノード規則と同じ |
| `geometry.type` | 必須 | `Point` |
| `properties.feature_type` | 必須 | `landmark` |
| `properties.scope` | 必須 | 常に `campus` |
| `properties.access_node_id` | 任意 | 到達ノード。`outdoor_node` で、`node_kind` が `destination`（§5） |

- `landmark` は `building_id` / `floor_id` を持たない。屋内の目印は `room` または将来の別種別で扱う。
- 既存資料の `lm_koku_shrine`（`map-data/normalized/landmark-coordinate-review.csv`）は本形式に合わないため、正式な ID を `campus_lm_{seq:03}` で新たに採番する。`lm_koku_shrine` は公開されたことがないため、参加者向けの alias として登録せず、移行の対応表に留める（E2-5 O-3a。最初の公開前の移行と外部参照の確認を条件とする）。
- 航空神社の座標は、写真位置と実測 Excel の約 117 m の差が未解消である（`map-data/README.md`）。本改訂はデータの確定を扱わない。

### 4.3 E2-5 の目的地種別との対応

E2-5 §5.4 の目的地種別（spot の解決元になれる `feature_type`）は、本改訂後、次の4つになる。

| `feature_type` | 由来 | geometry | 到達ノードの求め方（#37 の規則） |
|---|---|---|---|
| `building` | E1-4 v1（本改訂で `access_node_id` を追加） | Polygon | `access_node_id` があればそれ（§4.4）。無ければ `is_primary = true` の `formal_entrance` の `outside_node_id`。屋外直結の正式入口を登録しない建物（`ptb`・`aptr`、`map-data/README.md`）は `access_node_id` で指定する |
| `formal_entrance` | E1-4 v1 | Point | 自身の `outside_node_id`（屋外から）または `inside_node_id`（屋内から） |
| `room` | 本改訂 | Point | `access_node_id` |
| `landmark` | 本改訂 | Point | `access_node_id` |

E2-5 の `placement.access_node_id` には、解決元 Feature の `access_node_id` をそのまま入れる（`room` / `landmark`、および `access_node_id` を持つ `building`）。`access_node_id` を持たない `building` と `formal_entrance` では `null` とし、到達ノードは上表の規則で端末が `map.geojson` から求める（E2-5 §5.2 の「Feature の値と一致する」を保つため、派生値を `placement` に入れない）。

### 4.4 `building` の到達ノード（O-10 X3）

| 項目 | 必須 | 規則 |
|---|---|---|
| `properties.access_node_id` | 任意 | 建物の到達ノード。同じ `building_id` の `indoor_node` で、`node_kind` が `destination`（§5） |

- 建物を目的地にしたときの到達ノードを明示するための任意の項目である。指定が無ければ、従来どおり代表入口（`is_primary = true` の `formal_entrance`）の外側ノードを使う。
- 屋外直結の正式入口を登録しない建物（`ptb`・`aptr`。#16 の実測方針）は、この項目で到達ノードを指定する。正式入口の意味（屋外直結の入口、`outside_node_id` は `outdoor_node`）は変えない。
- どのノードを指定するかは、来場者が実際にどこから入るかの現地確認（E2-5 §11 O-10 手順1）の後に決める。推測で指定しない。
- 代表入口より適した到達点がある建物にも使える。
- `ptb`・`aptr` に屋内経由でたどり着くには、建物間の連絡路（例 `mb_ptb_f1_cor_001`）を経路グラフで表す必要があるが、現行の `walking_path`（`scope=indoor`）は両端が同じ `floor_id` であることを求めるため表せない。表し方は #42・E5 の屋内遷移契約で決める（E2-5 §11 O-10a）。
- 2.0.0 は未承認のため、任意の項目の追加による版の費用は生じない。

## 5. `node_kind: destination` の意味の変更

| | 1.0.0（現行の E1-4） | 2.0.0（本改訂） |
|---|---|---|
| `indoor_node` の `destination` | スポットとして公開可能なノード | `room` の到達ノード、または `building` の `access_node_id` が指す到達ノード |
| `outdoor_node` の `destination` | スポットとして公開可能なノード | `landmark` の到達ノード |

- **ノード ID を spot の ID にしない。** spot は目的地Feature（§4.3）からだけ解決する（E2-5 §5.4）。経路グラフの要素（`walking_path`・`indoor_node`・`outdoor_node`）は目的地種別に含めない。
- E1-3 は「経路計算専用ノードを参加者向け目的地として公開する必要が生じた場合も、基準データ上で対象を明示する」と定めている。本改訂は、その「明示」を目的地Featureと `access_node_id` の参照で行うものであり、E1-3 と矛盾しない。
- `junction` / `transition` / `entrance_approach` の意味は変えない。

## 6. 表示名（O-1c、R-7 で判断済み）

- `room` / `landmark` は `name` を持たない（スキーマで `name` を許可しない）。参加者向けの表示名の正本は Spot 公開版の `name` とする（E2-5 §5.2）。
- spot として公開されていない `room` / `landmark` は、参加者に表示しない（E2-5 §5.4）。地図上に名前のない点を出さない。
- `building` の `name`、`formal_entrance` の `name` は現行どおりとする。
- Studio の Map Editor は、編集中の表示に Spot の下書き名を使ってよい。これは payload の内容ではない。
- 編集用の内部名を Feature に持たせる案は採らない。bundle の `map.geojson` は公開した payload をそのまま配信するため（E2-5 §5.2）、payload に入れた名前は参加者にも届き、Spot の名前と二重になる。
- `building` の `name` は、その建物を目的地として表示するときの名前ではなく、**ほかの地点の所在する建物の名前**（例「教室棟・2F」）に使う。建物を spot として表示するときの名前は Spot 公開版の `name` とし、両者の不一致は Studio の公開前検証で警告する（E2-5 §5.2）。

## 7. geometry（O-1b、R-6 で判断済み）

- `room` / `landmark` は `Point` に限る。
- 部屋の外形（Polygon）が必要になった場合は、`room` の geometry を変えず、`room_id` で `room` を参照する別の種別（例：`room_outline`）を追加する。種別の追加なので minor 版で導入できる。`room` の geometry 型を Point から変えると major になるため、この方式を採る。
- 屋内の点の座標は、#36（フロアごとのアンカーと floor-local 座標）が揃うまで公開できない。本改訂はこのデータ不足を解消しない。
- Point に限る理由：E2-5 §5.2 は `placement.point` を「Point ならその座標、Polygon なら null（重心などを推測して埋めない）」と定めており、ピンの位置を常に示せるのは Point だけである。Polygon と Point の両方を許すと Polygon の部屋にピンを置けず、代表点を properties に持たせると座標が geometry の外に出て E1-4・E1-5 の検証と変換規則から外れる。
- **部屋の外形の表し方は #36・#38・#24 で決める。** #36 はフロアごとの canonical SVG を作り、#38 がその SVG フロアマップを描画する計画であり、部屋の形は GeoJSON ではなく SVG フロアマップで表示される可能性がある。GeoJSON で表すと決めた場合は、`room` の geometry を変えず、`room_id` で参照する別の種別をマイナー版で追加する。
- `landmark` の外形は v1.0 では扱わない。

## 8. 到達ノード（O-1d、R-5 で判断済み）

- `access_node_id` はスキーマ上**任意**とする。経路グラフ（#32・#39）の作成前でも、部屋・ランドマークの位置を公開できるようにするためである。
- `access_node_id` が無い目的地は「位置は分かるが経路は対象外」として扱う。E2-5 の `placement.access_node_id` が `null` になり、iOS は経路確認を出さない（表示の詳細は #85）。
- publish validator は、`access_node_id` の欠落を**警告**とし、公開を止めない。経路グラフは対象範囲（mb / ptb の屋内など）から段階的に作られるため、全目的地に必須とすると公開できなくなる。
- **主要6経路（#33）の目的地は例外とし、到達ノードがそろっていることを #79 の受け入れ試験で確認する。** 対象は ctc2 受付・`hgr_a`・`hgr_b`（建物）・mb / ptb の正式入口であり、建物と正式入口は §4.3 の規則で到達ノードを求める。ただし `ptb` は屋外直結の正式入口が登録の対象外であり（`map-data/README.md`）、`building.access_node_id` で到達ノードを指定する（§4.4、O-10 X3）。#33 の「屋外→ptb 正式入口」は、現地確認の結果に合わせて文言を改める（E2-5 §11 O-10 手順4）。ctc2 受付を `room` とするか別の目的地とするかはデータ作成（#39）で決める。

## 9. 判断事項

| ID | 論点 | 結論 | 影響 |
|---|---|---|---|
| R-1 | 版番号 | **決定（2026-10-21 利用者判断）：2.0.0**（§3） | スキーマファイル名、reader の受付範囲、E2-5 の例 |
| R-2 | 種別の分け方（E2-5 O-1a） | **決定（2026-10-21 利用者判断）：`room` と `landmark` の2種**（§4、§10） | スキーマ、Studio Map Editor |
| R-3 | 部屋 ID 規則の昇格 | **決定（2026-10-21 利用者判断）：Studio 決定事項26 を nexus-mobile `E1-7` として昇格させてから本改訂を承認する**。昇格案は [E1-7 草案](E1-7-room-canonical-ids.md)（未承認） | `room.id` の規則の正本 |
| R-4 | ランドマークの ID 形式 | **決定（2026-10-21 利用者判断）：`campus_lm_{seq:03}`**（§4.2）。E1-1・E1-2 が建物以外を連番にしていることに揃え、表示名に依存しない。既存の `lm_koku_shrine` は新しい ID へ移す | `landmark.id` の規則、既存資料の ID |
| R-5 | 到達ノード欠落の扱い（E2-5 O-1d） | **決定（2026-10-21 利用者判断）：警告とし、主要6経路の目的地だけ #79 で確認する**（§8） | Studio validator の公開阻止条件 |
| R-8 | 正式入口を持たない建物の到達ノード（E2-5 O-10） | **決定（2026-10-21 利用者判断）：`building` に任意の `access_node_id` を追加する**（§4.4）。`ptb`・`aptr` はこれで到達ノードを指定し、正式入口の意味は変えない。どのノードにするかは現地確認の後に決める。建物間の連絡路の表し方は #42・E5 で決める | スキーマ、Studio validator、#33・#39 |
| R-6 | geometry（E2-5 O-1b） | **決定（2026-10-21 利用者判断）：`room` / `landmark` は Point のみ**。部屋の外形の表し方（GeoJSON の別種別か SVG フロアマップか）は #36・#38・#24 で決める（§7） | ピンの位置、iOS の描画、将来の版 |
| R-7 | 表示名（E2-5 O-1c） | **決定（2026-10-21 利用者判断）：`room` / `landmark` は `name` を持たず、Spot 公開版の `name` を正本とする**。`building` の `name` は所在する建物の名前に使い、建物の Spot の名前との不一致を警告する（§6） | スキーマ、Studio の公開前検証 |

## 10. 却下した選択肢

| 案 | 却下理由 |
|---|---|
| ランドマークの ID を `lm_{slug}` とする（R-4） | 既存の `lm_koku_shrine` を活かせるが、E1-3 は表示名から ID を生成しないことを求めており、slug の決め方と表記揺れの防止を別に規則化する必要がある。E1-1・E1-2 は建物以外を連番にしている |
| 1種 `destination` ＋ `destination_type` 属性 | 屋内（建物・階が必須）と屋外（建物・階を持たない）で必須属性が異なり、JSON Schema の `feature_type` による判別が条件分岐だらけになる。種別ごとに分ける方が既存の E1-4 の書き方に合う |
| `room` の geometry を Polygon（重心をピンにしない規則のもと代表点を properties に持つ）とする | 座標が geometry の外に出て E1-4・E1-5 の検証と変換規則から外れる。外形のデータ（#36）もまだ作れない |
| 部屋は Point で始め、外形が必要になったら `room` の geometry を Polygon に変える | geometry の型の変更はメジャー版になる。別の種別の追加ならマイナー版で済む |
| `room` の geometry に最初から Polygon を許す | 部屋の外形には #36 の floor-local 座標とアンカーが必要で、現時点で作れない。将来は別種別で追加すれば minor で済む（§7） |
| Feature に編集用の内部名を持たせ、参加者には使わない | `map.geojson` は公開した payload をそのまま配信するため取り除けず、実質的に名前の二重管理になる |
| Feature の `name` を表示名の正本とし、Spot は名前を持たない | Studio 28 S4-2（名称は Spot 単独で公開）の撤回が必要になり、名前の修正のたびに地図の公開が必要になる |
| `room` / `landmark` に `name` を持たせる | Spot 公開版の `name` と二重管理になり、地図版と Spot 版で表示名がずれうる（E2-5 O-1c） |
| `ptb`・`aptr` にも屋外の正式入口を実測して登録する（O-10 X1） | #16 の実測方針（`ptb`・`aptr` は屋外直結入口の対象外）を覆すことになり、屋外の扉が実在するかも確認されていない |
| 建物間の連絡口も `formal_entrance` として登録する（O-10 X2） | `outside_node_id` は `outdoor_node` という正式入口の契約に反し、意味の変更（メジャー版）になる |
| `ptb`・`aptr` は建物としては目的地にせず、中の部屋だけを目的地にする（O-10 X4） | 来場者が「実習棟」を選べず、#33 の経路定義も作り直しになる |
| `access_node_id` を最初から必須にする | 経路グラフの作成前に部屋の位置を公開できなくなる（§8） |
| 1.1.0（minor）として意味の変更を例外扱いにする | E1-4 の版管理規則（列挙値の意味の変更は major）に例外を作る。1.0.0 の公開実績がないため major の実害は小さい（§3） |
| `node_kind: destination` のノードを spot の解決元として残す | E2-5 O-1 案1（目的地Featureを正本とする）と二重の解決経路になる。部屋の種別・所属を表す属性もノードにはない |

## 11. 承認後の作業（本書の範囲外。別 PR で行う）

| 担当 | 作業 |
|---|---|
| NexusMobile | E1-4 本文への反映、E1-2 の ID 体系表へのランドマーク（`campus_lm_{seq:03}`）の追加、`map-dataset-geojson-v2.schema.json` の新設、正常例・異常例の追加、map-dataset CLI（`tools/map-dataset`）の対応設定と生成の更新、E2-5 の参照の確定 |
| NexusMobile | admin-api の `MapDatasetValidator` は E2-5 §8.1 により Studio のテストとの突合後に削除する予定であり、2.0.0 へは更新しない |
| NexusStudio | v2 スキーマのコピーと `PinnedSchemaHashTests` の hash の更新、`MapDatasetValidator` の 2.0.0 対応（ID と `room_type`・`floor_id` の一致、`access_node_id` の参照先と `node_kind`、到達ノードの欠落警告、alias 名前空間との衝突） |
| NexusMobile（iOS、#22） | bundle の `map.geojson` を 2.x として読み込む |

## 12. validator に追加する検査（E1-4「JSON Schema と validator の責務」への追記案）

JSON Schema で検査するもの:

- `room.id` の字句形式と、`id` の `{floor_id}`・`{room_type}` 部分の形式
- `landmark.id` の字句形式（`^campus_lm_(?:00[1-9]|0[1-9][0-9]|[1-9][0-9]{2})$`。E1-2 の屋外ノード ID と同じ連番の書き方）
- `room_type` の列挙値、`landmark.scope` の固定値
- `room` / `landmark` が `name` を持たないこと

validator で検査するもの:

1. `room.id` の `{floor_id}` 部分が `properties.floor_id` と、`{room_type}` 部分が `properties.room_type` と一致すること。
2. `access_node_id` の参照先が存在し、`room` では同じ `floor_id` の `indoor_node`、`landmark` では `outdoor_node`、`building` では同じ `building_id` の `indoor_node` であり、いずれも `node_kind: destination` であること。
3. `node_kind: destination` のノードが、どの `room` / `landmark` / `building` からも参照されていない場合は警告とすること。
3a. 正式入口（`formal_entrance`）を持たず、`access_node_id` も持たない `building` は、到達ノードを求められないため警告とすること（§4.4、§8 と同じく公開は止めない）。
4. `room` / `landmark` の `access_node_id` 欠落を警告とすること（§8）。
5. `room` / `landmark` の `id` が、E2-5 §5.5 の ID 予約表（一度でも公開された ID と alias）および現在の draft の ID と衝突せず、`retired` の ID を再利用しないこと。
