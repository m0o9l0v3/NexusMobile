# 下書き（公開しない）

構内の屋外経路の下書き。オーナーが現地の知識から作った（2026-11-18、#211 のコメント）。**座標・距離はまだ無い**。現地測量（[`docs/map-data/campus-survey-plan.md`](../../docs/map-data/campus-survey-plan.md)）で埋める。

| ファイル | 内容 | 状態 |
|---|---|---|
| `campus_nodes_draft.csv` | 屋外経路ノード 13 点（`campus_n_001`〜`campus_n_013`、旧ラベル `N01`〜`N13`） | 位置は未測量 |
| `campus_edges_draft.csv` | 屋外経路の辺 14 本（`campus_e_001`〜`campus_e_014`） | `distance_m` は空欄。`status=needs_measurement`（`campus_e_014` は `optional_verify_on_site`＝通れるかを現地で確かめる） |

- ID は E1-2（`campus_n_{seq:03}`）と E1-4（屋外辺 `campus_e_{seq:03}`）に従う。採番した ID は変えず、使わなくなっても再利用しない。
- map-dataset の対応設定（`campus-buildings.config.json`）はこの下書きを読まない。配布の GeoJSON には入らない。
- `node_kind`（`junction`・`entrance_approach`）と `connected_buildings` はオーナーのメモで、E1-4 の `outdoor_node` の契約に合わせるのは、測量のあとに正規化するとき。

## 測量でどう埋めるか

1. 各ノードを、測量設定（`survey-project.json`）の `points` に `kind: "node"` で登録する（ID はこの CSV の `node_id`）。
2. 道路に沿った基線（例: `campus_n_001`→`campus_n_002`）を `baselines` に登録し、ノード・分岐・入口前の点を **累積距離＋支距** で測る。ノードには、国土地理院で確かめた古い棟の角からの距離を最低 1 本足す（累積距離だけでは位置が決まらない。計画書 §4.7）。
3. 分岐の無い曲がり角は、ノードにせず `kind: "bend"` の折れ点として測り、辺の途中の頂点にする（計画書 §4.6）。
4. 各辺を `edges` に `{ "id": "campus_e_001", "points": ["campus_n_001", "<折れ点>…", "campus_n_002"] }` と書く。
5. `npm run mapdata:survey -- … --points-out nodes.geojson --routes-out edges.geojson` で、ノードの Point と辺の LineString が出る。辺の `distance_m` は、調整後の座標でつないだ折れ線の長さ（0.1 m 単位）。
6. 出た値でこの CSV の `distance_m` を埋め、`status` を `measured` にする。正規化ソース（`map-data/normalized/`）への移し方と配布への入れ方は、#16・#39 で決める。
