# 構内の地面（campus_ground）の作図手順

- 根拠: [E1-4 改訂2](decisions/E1-4-r2-campus-ground.md)（状態: 採用）§4・§6 の2
- 作業する人: オーナー（範囲を作図し、承認する。開発チームは値を作らない。§4.2）
- 前提: map-dataset CLI が `campus_ground` に対応していること（m0o9l0v3/NexusMobile#147）

構内に不透明な「地面」を描き、構内では Apple の地図の建物を見せないようにする（§3）。この手順で、その地面の範囲を QGIS で作図し、地図のデータ（GeoJSON 2.1.0）へ取り込み、Studio で確かめるまでを行う。

## 1. 何を描くか

構内（敷地）の範囲を、**穴の無い1つの多角形**で描く。

| 条件 | 理由 |
|---|---|
| すべての建物（14棟）が中に入る | 地面からはみ出した建物の部分は、Apple の地図の上に浮いて見える。Studio は `building_outside_campus_ground` で公開を止める |
| 建物の縁ぎりぎりに引かず、周りに余裕を持たせる | Apple の地図の建物は、Nexus の建物より南東へ数 m ずれている（§2）。縁ぎりぎりだと、地面の外に Apple の建物の輪郭がのぞく |
| 構内の外の公道は含めない | 周りの道路は、構内の位置を知る手がかりとして Apple の地図のまま見せる（§3）。特に西側の公道 |
| Studio の承認済み設定の `campusBoundary` の中に収める | 地面も地図の Feature の1つなので、許容範囲の外に出ると `outside_campus` で公開が止まる |
| 穴を作らない・1つだけ | 構内の中の空き地なども地面で覆う。JSON Schema が穴・2つ目を拒否する |

`campusBoundary`（6頂点）をそのまま写して使わない。公開判定のための許容範囲で、西側の公道と南側の広い区画まで含んでいる（§4.2）。

余裕を何 m 取るか、敷地のどこまでを構内とするか（駐車場・グラウンドなど）は、オーナーが決める。決めたことは §5 の記録に書く。

## 2. QGIS の準備

1. 新しいプロジェクトを開き、プロジェクトの座標系を **EPSG:4326（WGS 84）** にする。
2. 背景に航空写真を加える。「XYZ Tiles」に新しい接続を作り、URL に地理院タイル「全国最新写真（シームレス）」を指定する。
   - URL: `https://cyberjapandata.gsi.go.jp/xyz/seamlessphoto/{z}/{x}/{y}.jpg`
   - 最大ズームレベル: 18（19 以上は無い）
   - 出典の表示が要る（「地理院タイル」）。作図に使うだけで、この画像を地図のデータやアプリには入れない。
3. 建物の原本（`確定版geojson/nexus_campus_canonical_20260724.geojson`）をレイヤーとして重ねる。
   - 航空写真は古く、7棟（CTC・CTC2・Da Vinci Hall・女子寮・格納庫A・格納庫B・技能審査棟）が写っていない（§2）。これらの建物は原本の形で位置を確かめる。
4. 必要なら入口の実測（`map-data/normalized/entrances.csv`）を、経度・緯度の列から点のレイヤーとして重ねる。

## 3. 作図

1. 新しいレイヤーを作る（「新規 GeoPackage レイヤー」など）。
   - ジオメトリの種類: **ポリゴン**（マルチポリゴンにしない。CLI は `MultiPolygon` を `geometry_type_mismatch` で拒否する）
   - 座標系: EPSG:4326
   - 属性に文字列の項目 `id` を1つ作る
2. 構内の範囲を1つの多角形で描き、属性 `id` に `campus_ground` と入れる。
3. 頂点の数は、敷地の形が分かる程度でよい。細かく描き込みすぎない。
4. 描いたら、建物のレイヤーを重ねたまま、すべての建物が中に入っていること、公道を含んでいないことを目で確かめる。

頂点の向き（時計回り・反時計回り）と閉じ方は気にしなくてよい。CLI が反時計回りに直し、直したことをレポートに書く。

## 4. 書き出しと置き場所

1. レイヤーを右クリックし、「エクスポート」→「地物の保存」で GeoJSON に書き出す。
   - 座標系: EPSG:4326
   - ジオメトリの種類: ポリゴン（「マルチタイプを強制」は外す）
   - レイヤーのオプション: **`RFC7946` を `YES`** にする。QGIS は既定で `crs` メンバーを書き出し、CLI はそれを `legacy_crs_member` で拒否する（そのとき、対応する地物も見つからず `missing_source_feature` が続けて出る）
   - 座標の精度: 6桁以上（CLI が小数6桁に丸める）
2. ファイル名に作図日を付け、建物の原本と同じ原本フォルダ（`--input-root` に渡すフォルダ）の `確定版geojson/` に置く。
   - 例: `確定版geojson/nexus_campus_ground_YYYYMMDD.geojson`
   - 原本は読み取り専用として扱い、描き直したら日付を変えた新しいファイルにする。

## 5. 承認の記録

作図した範囲を地図のデータに取り込む前に、`map-data/raw/<作図日>/campus-ground.md` に次を書いてコミットする（入口写真の原本記録 `map-data/raw/2026-09-19/` と同じく、原本はリポジトリに入れず、同じものか確かめられる値を残す）。

| 項目 | 内容 |
|---|---|
| ファイル名 | 例: `nexus_campus_ground_YYYYMMDD.geojson` |
| SHA-256 | `shasum -a 256 <ファイル>` の値 |
| 作図した人・日 | |
| 承認した人・日 | オーナー（GitHub のユーザー名） |
| 背景に使ったもの | 例: 地理院タイル「全国最新写真（シームレス）」、建物の原本 |
| 決めたこと | 構内に含めた範囲・含めなかった範囲（公道・駐車場など）、建物の周りの余裕 |

## 6. 地図のデータへ取り込む

対応設定 [`tools/map-dataset/config/campus-buildings.config.json`](../tools/map-dataset/config/campus-buildings.config.json) に、原本と Feature を1つずつ加える。

`sources` に加える:

```json
"campus_ground_geojson": {
  "kind": "geojson",
  "path": "確定版geojson/nexus_campus_ground_YYYYMMDD.geojson",
  "source_id_property": "id"
}
```

`features` に加える:

```json
{
  "source": "campus_ground_geojson",
  "source_id": "campus_ground",
  "decision": "include",
  "feature_type": "campus_ground",
  "canonical_id": "campus_ground",
  "properties": { "scope": "campus" }
}
```

`canonical_id` は必ず `campus_ground`、`scope` は必ず `campus`（ほかの値は JSON Schema が拒否する）。地面を出力すると、地図の `schema_version` は自動で 2.1.0 になる。

続けて生成と検証をする（コマンドの詳細は [E1-6](e1-6-map-dataset-conversion.md)）。実データには地面と関係の無い blocker（経路グラフなど）が残っているため、今は `--allow-draft` が要る。

```bash
npm run mapdata -- generate \
  --config tools/map-dataset/config/campus-buildings.config.json \
  --input-root "<原本フォルダの絶対パス>" \
  --out /tmp/nexus-campus.geojson \
  --report /tmp/nexus-campus.report.json \
  --allow-draft
```

```bash
npm run mapdata -- validate \
  --input /tmp/nexus-campus.geojson \
  --report /tmp/nexus-campus.validate.json
```

- 出力の `nexus.schema_version` が `2.1.0` で、`campus_ground` の Feature が1つあること。
- レポートに `legacy_crs_member`・`geometry_type_mismatch`・`invalid_ring`・`schema_violation` が出たら、§3・§4 に戻る。
- 形を目で見たいときは、出力を geojson.io に貼る（E1-6「geojson.io での目視確認」）。

CLI は「建物が地面に入るか」を調べない（Studio の検証器の責務）。次の §7 で確かめる。

## 7. Studio で確かめる

生成した GeoJSON を Studio に取り込む（m0o9l0v3/NexusStudio#33 以降）。

| 確かめる場面 | 結果 | 意味と対応 |
|---|---|---|
| 取り込み | `building_outside_campus_ground （<建物の ID>）` で取り込みが失敗する | その建物が地面からはみ出している。§3 で範囲を広げて描き直す |
| 公開の確認 | `outside_campus` に `campus_ground` が出る | 地面が `campusBoundary` の外に出ている。§1 の条件どおりに描き直す |
| 両方 | 地面について何も出ない | 範囲の条件は満たしている |

建物の検査は取り込みのときに行い、`campusBoundary` の検査は公開の確認のときに行う（承認済み設定を使うため）。実データの地図は、経路グラフなどが揃うまで Studio で公開できない（地面とは別の理由）。この段階では、地面に関する指摘が出ないことだけを確かめる。

## 8. この後

- 地面の見た目（色・枠・構内の外との境目）は Figma で決める（§6 の5）。
- iOS で地面を描き、Apple の地図の建物が隠れること、構内の外の道路が見えることをシミュレーターで確かめる（§6 の6・7）。範囲が狭くて Apple の建物がのぞくときは、§3 に戻って余裕を広げる。
- 描き直したときは、§4 の新しいファイル、§5 の新しい記録、§6 の `path` の更新を1組で行う。
