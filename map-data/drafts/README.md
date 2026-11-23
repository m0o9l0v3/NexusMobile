# 下書き（公開しない）

構内の屋外経路の下書き。オーナーが現地の知識から作り（2026-11-18、#211 のコメント）、#32 でトポロジーと通行属性を確定した。**座標・距離はまだ無い**。現地測量（[`docs/map-data/campus-survey-plan.md`](../../docs/map-data/campus-survey-plan.md)）で埋める。

| ファイル | 内容 | 状態 |
|---|---|---|
| `campus_nodes_draft.csv` | 屋外経路ノード 25 行（`campus_n_001`〜`campus_n_025`。有効 23 点・不使用 `retired` 2 点：`campus_n_011`・`campus_n_016`） | 位置は未測量（座標なし） |
| `campus_edges_draft.csv` | 屋外経路の辺 32 行（`campus_e_001`〜`campus_e_032`。有効 29 本・不使用 `retired` 3 本：`campus_e_007`・`campus_e_014`・`campus_e_026`） | `distance_m` は空欄（未測量）。有効 29 本は `status=needs_measurement` |

- ID は E1-2（`campus_n_{seq:03}`）と E1-4（屋外辺 `campus_e_{seq:03}`）に従う。採番した ID は変えず、使わなくなっても再利用しない。
- 確定済みの通行属性：有効 29 本はすべて `bidirectional=true`。`campus_e_025` のみ `path_kind=stairs` / `accessibility=not_accessible`、他の有効 28 本は `path_kind=walkway` / `accessibility=accessible`。通常歩行（有効 29 本）・車いす（`accessibility=accessible` の 28 本）とも、正門（`campus_n_001`）から全有効 23 点へ到達可能。
- map-dataset の対応設定（`campus-buildings.config.json`）はこの下書きを読まない。配布の GeoJSON には入らない。
- `node_kind`（`junction`・`entrance_approach`）と `connected_buildings` はオーナーのメモで、E1-4 の `outdoor_node` の契約に合わせるのは、測量のあとに正規化するとき。

## 未確定事項（現地確認・承認待ち）

1. **`road_arena_ctc_pk` の区間矛盾（実測 148 m と GPS 直線約 250.6 m）**：対象区間と食い違い原因は未確定（現地確認待ち）。未確定の距離・重みは採用しない。
2. **座標・距離・所要時間（`distance_m`・`estimated_seconds`）**：国土地理院の測量成果使用承認（測量法第30条）と現地測量（[`docs/map-data/campus-survey-plan.md`](../../docs/map-data/campus-survey-plan.md)）までは空欄・未確定のまま維持する。

## 測量でどう埋めるか

1. 各ノードを、測量設定（`survey-project.json`）の `points` に `kind: "node"` で登録する（ID はこの CSV の `node_id`）。
2. 道路に沿った基線（例: `campus_n_001`→`campus_n_002`）を `baselines` に登録し、ノード・分岐・入口前の点を **累積距離＋支距** で測る。ノードには、国土地理院で確かめた古い棟の角からの距離を最低 1 本足す（累積距離だけでは位置が決まらない。計画書 §4.7）。
3. 分岐の無い曲がり角は、ノードにせず `kind: "bend"` の折れ点として測り、辺の途中の頂点にする（計画書 §4.6）。
4. 各辺を `edges` に `{ "id": "campus_e_001", "points": ["campus_n_001", "<折れ点>…", "campus_n_002"] }` と書く。
5. `npm run mapdata:survey -- … --points-out nodes.geojson --routes-out edges.geojson` で、ノードの Point と辺の LineString が出る。辺の `distance_m` は、調整後の座標でつないだ折れ線の長さ（0.1 m 単位）。
6. 出た値でこの CSV の `distance_m` を埋め、`status` を `measured` にする。正規化ソース（`map-data/normalized/`）への移し方と配布への入れ方は、#16・#39 で決める。
