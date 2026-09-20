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

`normalized/landmark-coordinate-review.csv` は `IMG_2673.HEIC` の撮影位置と既存実測Excelの座標差を記録する。両者は約117 m離れているため、`lm_koku_shrine` の正式座標としては未採用とする。写真地点が航空神社そのものか、進入地点かを現地確認してから確定する。

## 写真原本

HEIC原本は容量と位置情報の機微性を考慮してリポジトリへ複製しない。`raw/2026-09-19/entrance-photo-metadata.csv` にファイル名、SHA-256、ファイルサイズ、EXIF値を保存し、手元の原本との同一性を確認できるようにする。
