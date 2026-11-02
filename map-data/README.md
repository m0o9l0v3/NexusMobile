# Map data source layers

MapDataset の座標データは、原本、正規化ソース、配布生成物を分離して管理する。

| 層 | パス | 役割 |
|---|---|---|
| 原本記録 | `raw/<date>/` | 実測・撮影時点の値、証拠ファイルのハッシュ、抽出条件を保存する |
| 正規化ソース | `normalized/` | canonical ID と座標を対応付け、生成処理へ渡せる形に整理する |
| 配布生成物 | 将来追加 | JSON Schema に適合し、参照整合と公開条件を満たした GeoJSON だけを置く |

## 入口座標

`normalized/entrances.csv` は、2026-07-19 と 2026-09-19 に撮影した入口写真の EXIF GPS と、ユーザーが確定した写真・canonical ID 対応を正規化したもの。

- `mb_ent_001` は、ユーザーが Google Maps で入口位置として確定した座標を採用する。`IMG_2922.HEIC` の EXIF GPS は根拠写真の撮影位置として原本記録に残す。
- `hgr_a` と `hgr_b` は別の建物・別の入口IDを維持する。同じ `route_approach_group=hgr_ab_shared` と座標を持ち、経路グラフ作成時に同一の `outside_node_id` へ接続する。
- `ptb` と `aptr` は屋外直結入口の対象外なので登録しない。
- 写真GPSは撮影者の位置である。ユーザーが各入口地点で撮影したとの確認に基づき、接続情報未確定の実測座標として記録する。

正式な `formal_entrance` Feature には `floor_id`、`outside_node_id`、`inside_node_id`、`is_primary` が必要である。これらが未確定の間は、正規化CSVを配布GeoJSONへ変換しない。

## 航空神社

`normalized/landmark-coordinate-review.csv` は `IMG_2673.HEIC` の撮影位置と既存実測Excelの座標差（約117 m）を記録する。2026-11-02 に利用者が**写真の撮影位置を正式座標に採用**した（m0o9l0v3。撮影位置の水平精度は約18 m）。ID は E1-4 改訂1 R-4 の形式で `campus_lm_001` とし、旧 ID `lm_koku_shrine` は同じ CSV の `legacy_id` 列に移行の対応として残す（参加者向けの alias にはしない。E2-5 O-3a）。

地図データでは、この CSV の `status=adopted_photo` の行を `csv_points` ソース（`landmark_coordinates`）として読み、`campus_lm_001` の Point を作る（`tools/map-dataset/config/campus-buildings.config.json`）。原本 GeoJSON の `lm_koku_shrine` は旧座標なので除外する。

## 写真原本

HEIC原本は容量と位置情報の機微性を考慮してリポジトリへ複製しない。`raw/2026-09-19/entrance-photo-metadata.csv` にファイル名、SHA-256、ファイルサイズ、EXIF値を保存し、手元の原本との同一性を確認できるようにする。
