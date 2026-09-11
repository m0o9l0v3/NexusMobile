# E1-6: MapDataset GeoJSON 変換・検証ツールの使い方

- 対象Issue: [#15 「[E1-6] Excel/QGIS → GeoJSON 変換スクリプトを実装する」](https://gitlab.com/11h27m/nexus-mobile/-/work_items/15)
- 実装: [`tools/map-dataset/`](../tools/map-dataset/)
- 実装契約（優先順位順）:
  1. [`docs/schemas/map-dataset-geojson-v1.schema.json`](schemas/map-dataset-geojson-v1.schema.json)
  2. [`docs/decisions/E1-4-geojson-schema.md`](decisions/E1-4-geojson-schema.md)
  3. [`docs/decisions/E1-5-coordinate-reference-system.md`](decisions/E1-5-coordinate-reference-system.md)
  4. [`docs/decisions/E1-1-building-canonical-ids.md`](decisions/E1-1-building-canonical-ids.md)
  5. [`docs/decisions/E1-2-hierarchical-ids.md`](decisions/E1-2-hierarchical-ids.md)
  6. [`docs/decisions/E1-3-spot-id-integration.md`](decisions/E1-3-spot-id-integration.md)

このツールは、実地調査の原本（QGIS から書き出した GeoJSON、実地調査 Excel）から MapDataset の
GeoJSON payload を**決定的に再生成**し、既存の JSON Schema と E1-5 の座標契約で**検証**する。

## 絶対に守ること

- **原本を変更しない。** ツールは原本を読み取り専用で開く。出力先は必ず引数で指定した別ファイル。
- **未確認値を推定しない。** 座標系不明・軸順不明・単位不明・測定方法不明・精度不明の値は、
  補完も推定も行わず明示的な検証エラーにする。仮のアンカーや仮の座標を作らない。
- **設定にない地物を黙って除外しない。** 原本の地物は1件ずつ、採用（canonical ID つき）か
  除外（理由コードと理由つき）かを対応設定に書く。書かれていない地物があれば失敗する。
- **既存スキーマ・決定記録を変換処理に合わせて緩めない。** 実装側を契約へ合わせる。

## 必要環境

- Node.js 20 以上（開発・確認は Node 24 で実施）。
- 追加依存は `ajv`（JSON Schema Draft 2020-12 検証）のみ。Excel 読み取りは Node 標準の
  `node:zlib` だけで動く自前リーダーを同梱している（理由は末尾「依存の選定」）。
- 初回のみ依存をインストールする。

```bash
npm run mapdata:install
```

## 入力の役割

| 入力 | 役割 |
|---|---|
| QGIS 由来の canonical GeoJSON | 屋外 geometry（WGS 84）の供給元。`properties.id` と Feature 直下 `id` の両方を追跡する |
| 実地調査 Excel（`IDマスター` 等） | canonical ID と表示名のレジストリ、アンカー入力。シート名と列名は対応設定で明示する |
| 対応設定 JSON（mapping config） | 「どの原本のどの地物を、どの canonical ID・どの Feature 種別で採用／除外するか」の唯一の正 |
| `--input-root` | 対応設定に書いた相対パスを解決する原本フォルダ。絶対パスをコードや設定へ埋め込まない |
| `--schema` | MapDataset JSON Schema。既定は `docs/schemas/map-dataset-geojson-v1.schema.json` |

対応設定の形式は [`tools/map-dataset/src/config.schema.json`](../tools/map-dataset/src/config.schema.json)
が正本で、実例は [`tools/map-dataset/config/campus-buildings.config.json`](../tools/map-dataset/config/campus-buildings.config.json)。

主な項目は次のとおり。

- `sources`: 原本の宣言。`geojson` / `excel` / `inline` の3種類。
  `excel` はシート名・ヘッダー行・列名マップ・行フィルタ・必須値を明示する（列名の推測はしない）。
  `inline` は「原本ではなく設定に直接書いた値」であることを `origin_note` で必ず明示する。
- `building_registry`: 表示名の突き合わせに使う Excel ソース。
- `floors`: `nexus.floors` に出すフロアレジストリ。
- `indoor_transforms`: フロアごとの基準点とアンカー（E1-5 の入力契約）。
- `features`: 原本の地物1件につき1エントリ。`decision` が `include` なら
  `feature_type` と `canonical_id` が必須、`exclude` なら `reason_code` と `reason` が必須。
- `name.policy`: 表示名の決め方。`require_agreement`（原本とレジストリが一致したときだけ採用）/
  `from_source` / `explicit` / `omit`（理由必須）。
- `reserved_ids`: canonical ID と衝突させない予約済み識別子。
- `publish_readiness.blockers`: 公開に足りていない実データを明示する欄。

## 実行例

### generate（再生成）

```bash
npm run mapdata -- generate \
  --config tools/map-dataset/config/campus-buildings.config.json \
  --input-root "<原本フォルダの絶対パス>" \
  --out /tmp/nexus-campus-buildings.geojson \
  --report /tmp/nexus-campus-buildings.report.json \
  --check-determinism
```

### validate（既存または生成済み GeoJSON の検証）

```bash
npm run mapdata -- validate \
  --input /tmp/nexus-campus-buildings.geojson \
  --report /tmp/validate.report.json
```

### 実データの不足を成功扱いにしたくないとき

`--require-publish-ready` を付けると、`publish_readiness.blockers` が1件でもある限り
終了コード 1 で失敗し、出力を書き出さない。

```bash
npm run mapdata -- generate \
  --config tools/map-dataset/config/campus-buildings.config.json \
  --input-root "<原本フォルダの絶対パス>" \
  --out /tmp/out.geojson \
  --require-publish-ready
```

ツールのディレクトリから直接実行することもできる。

```bash
node tools/map-dataset/map-dataset.mjs --help
```

終了コードは `0`（合格）/ `1`（検証エラー、出力は書き出さない）/ `2`（引数・対応設定の誤り）。

## 出力の意味

`generate` は単一の `FeatureCollection` を書き出す。生成物は書き出す前に `validate` と同じ
検証経路を通る。保証する内容は次のとおり。

- `nexus.schema_version` は `1.0.0`。
- canonical ID は Feature 直下の `id` だけに置き、`properties.id` は出力しない。
- geometry と `properties.feature_type` の組み合わせは E1-4 のとおり固定。
- geometry は WGS 84（OGC CRS84）の2次元 `[longitude, latitude]`。`crs` メンバーと高度の第3要素は出力しない。
- longitude / latitude は小数6桁へ丸める。
- Polygon の環を閉じ、外環は反時計回り、内環は時計回りへ正規化する。
- 原本の未知プロパティ・表示用スタイル属性（`fill`、`stroke-width`、`styleUrl` など）は持ち込まない。
- floor と Feature を canonical ID のコードポイント順で安定ソートする。
- プロパティ順・インデント（半角2）・改行（LF）・末尾改行を固定し、同じ入力・設定から
  バイト単位で同じ出力を生成する。

## 検証レポートの意味

レポートは**実行時刻と絶対パスを含めない**ので、同じ入力なら内容もバイト単位で一致する。

| フィールド | 意味 |
|---|---|
| `status` | `ok` なら対応設定に書かれた範囲の変換と検証に合格した |
| `deterministic_generation_checked` | `--check-determinism` で2回生成し一致を確認したか |
| `config` / `inputs` | 対応設定と原本のファイル名と SHA-256（原本が差し替わったら気づける） |
| `output` | 生成物のファイル名・SHA-256・バイト数 |
| `counts` | 原本の地物数、採用数、除外数、失敗数 |
| `publish_readiness.ready` | **公開できるかどうか。実データが足りない間は必ず `false`** |
| `publish_readiness.blockers` | 公開に足りていない実データとその担当Issue |
| `transforms` | フロアごとの変換パラメータ、fit 残差、check 誤差、往復誤差、丸め誤差、許容値 |
| `trace` | 原本→出力の追跡情報（下記） |
| `errors` / `warnings` | 理由コード付きの所見 |

`trace` は原本の地物1件につき1件あり、次を保持する。

- `source.file`（原本ファイル）、`source.sheet` と `source.row`（Excel）、
  `source.feature_index`（GeoJSON）、`source.source_feature_id` と `source.source_property_id`（元ID）
- `canonical_id`、`feature_type`
- `result`: `included` / `excluded` / `failed`
- `reason_code` と `reason`: 除外・失敗の明示的な理由
- `dropped_properties`: MapDataset へ持ち込まなかった原本プロパティ
- `notes`: 環の閉鎖・向き反転・ID不一致の解決・floor-local 座標の変換など、行った正規化

`status` が `ok` でも `publish_readiness.ready` が `false` なら、それは
「対応設定に書いた範囲の変換は成功したが、公開に必要な実データはまだ揃っていない」という意味である。

## 屋内座標（floor-local → WGS 84）

E1-5 のとおり、floor-local XY から局所ENU への2次元相似変換と、局所ENU と WGS 84 の相互変換を実装している。
中間計算は倍精度で、途中では丸めない。距離比較はすべて局所ENUのメートルで行う（度数差を距離として扱わない）。

アンカーは次をすべて満たさないと失敗する。

- E1-5 の表にある全項目が埋まっている（`reported_accuracy_m` が `unknown` の記録は使わない）
- `fit` 3点以上、独立した `check` 1点以上、同一フロアで合計4点以上
- `fit` と `check` を同じ点で兼用していない
- 配置が退化していない（ツール側の追加ガードとして、最良直線からの垂直方向の広がりが
  1.0 m 未満、または主軸方向の広がりの5%未満なら拒否する。E1-5 の条件を緩めるものではない）

許容誤差（E1-5）: 数値往復誤差 各点 0.05 m 以下 / `fit` 残差 RMS 2.0 m 以下かつ各点 3.0 m 以下 /
`check` 誤差 各点 3.0 m 以下 / 小数6桁丸めの追加誤差 0.10 m 以下。
外れ値の無言除外、平均化による合格化、アフィン変換への変更は行わない。

## geojson.io での目視確認（任意）

再生成処理は geojson.io に依存しない。目視確認したいときだけ次の手順を使う。

1. `generate` で書き出した GeoJSON をテキストとして開き、全文をコピーする。
2. <https://geojson.io> を開き、右側のエディタへ貼り付ける。
3. 建物の位置・形・穴、ノードと経路の並びを地図上で確認する。
4. 手で直した場合は、**原本ではなく対応設定または原本側を直してから `generate` をやり直す。**
   どうしても手編集した GeoJSON を確認したいときは `validate` に通し、丸め桁数・環の向き・
   参照整合が崩れていないことを必ず確かめる。

QGIS の GUI 操作は自動化しない。QGIS 由来のデータは、QGIS から書き出した GeoJSON を入力として扱う。

## 現在不足している実データ

`tools/map-dataset/config/campus-buildings.config.json` で実データに対して `generate` すると、
建物14棟の Polygon だけが生成され、`publish_readiness.ready` は `false` になる。理由は次のとおり。

| blocker | 内容 | 担当 |
|---|---|---|
| `building_geometry_unmeasured` | 原本 metadata が `publishability: draft_only`。建物の `status` は `unmeasured` / `provisional` / `needs_review` / `confirmed` が混在し、航空写真と基盤地図情報からの仮作成を含む | #16 |
| `display_names_unconfirmed` | `ab` / `amh` / `dh` / `lbh` の表示名が原本間で不一致。E1-1 C-012 の公式表記確認が未了のため `name` を出力しない | E1-1 C-012 |
| `floors_not_registered` | 公開対象フロアと canonical SVG が未確定のため `nexus.floors` が空 | #36 |
| `floor_local_coordinates_missing` | どの原本にも floor-local 座標（`x_m` / `y_m`）列がない。廊下長は材料であってアンカーの代替にならない | #36 |
| `indoor_anchors_missing` | E1-5 のアンカー入力契約を満たす記録が原本にない。GPS実測記録の建物シートは境界点IDの座標のみで、floor-local 座標・測定方法・精度・承認記録がない | #36 |
| `formal_entrances_missing` | `入口データ` は `mb_ent_1`（canonical 形式外）1行のみで未測定。座標も接続ノードもない | #36 / #39 |
| `route_graph_missing` | 屋内ノード・屋外ノード・歩行経路の canonical データが未作成 | #16 / #39 |

汎用の変換処理とテストは完成しているので、上記が揃えば対応設定を足すだけで再生成できる。
不足している間は仮値を作らず、レポートへ明示して失敗・未達として扱う。

## E2-2 publish validator との責務境界

このツール（#15）が行うのは、Issue #15 に必要な最小範囲だけ。

実装済み:

- JSON Schema Draft 2020-12 による検証
- 入力値・ID対応・座標・次元・丸めの検証
- 変換に必要なアンカーと誤差条件の検証
- 決定的生成の検証（`--check-determinism`）
- 原本から出力までの追跡情報
- 生成後に同じ validator を通す処理
- 出力を安全に生成するうえで不可欠な整合検査（Feature id の重複、未定義の
  `floor_id` / `building_id` / ノード参照、親子不一致、環の閉鎖と向き、経路端点の一致、
  自己ループ辺、予約済み識別子との衝突）

このツールでは扱わない（E2-2 以降）:

- 完全な publish validator（到達不能ノード、孤立ノード、同一ノード間の重複辺、
  Polygon の自己交差、キャンパス許容範囲、入口 geometry と接続ノードの距離許容値、
  `distance_m` / `estimated_seconds` の geometry に対する許容誤差）
- DB（`spot_id_aliases` を含む alias 名前空間）・API・iOS との統合
- 全キャンパス経路グラフの到達可能性判定
- 実データの新規測定、未承認の入口・屋内ノード・経路・フロア構成の確定
- 原本データそのものの修正、#16 / #36 のデータ作成

`reserved_ids` は対応設定で明示したものだけを見る。E1-3 の alias レジストリは DB 側（E2 / E3）の
責務であり、ここから参照しない。

## 依存の選定

| 採否 | 対象 | 理由 |
|---|---|---|
| 採用 | `ajv`（^8.17.1） | Draft 2020-12（`prefixItems` / `items: false`）に対応した JSON Schema validator が必要。既存スキーマをそのまま正本として使える |
| 採用 | `typescript`（devDependency） | `checkJs` による `tsc --noEmit` 型検査のため。ビルド段階は増やさず、実行時は素の `.mjs` のまま |
| 不採用 | `xlsx`（SheetJS） | npm 上の最新が 0.18.5 で止まっており既知の脆弱性が残る |
| 不採用 | `exceljs` | 依存9件（`archiver` / `unzipper` / `jszip` など）で書き込み機能まで含み、読み取り専用の用途に対して過剰 |
| 不採用 | `read-excel-file` | 依存4件。セル値の型変換がライブラリ任せで、「未確認値を推定しない」契約に合わせるには結局独自の判定が必要 |
| 自前実装 | XLSX リーダー（`tools/map-dataset/src/sources/xlsx.mjs`） | Node 標準の `zlib.inflateRawSync` と ZIP central directory 解析だけで読める。セル値を生のまま返し、日付書式のセルは `ambiguous_cell_format` として拒否できるので、契約と実装が一致する |

テストは Node 標準の `node:test` を使い、テストランナーの依存を追加していない。

## 開発

```bash
npm run mapdata:test        # 正常系・異常系テスト（node:test）
npm run mapdata:typecheck   # tsc --noEmit（checkJs）
```

テスト用の Excel フィクスチャ（`tools/map-dataset/test/fixtures/id-master.xlsx`）は
`tools/map-dataset/test/fixtures/make-id-master-xlsx.py` で再生成できる。中身は契約確認用の
最小合成データで、実測原本の値は複製していない。
