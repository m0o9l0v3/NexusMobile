# map-dataset

Nexus MapDataset GeoJSON の再生成・検証 CLI（E1-6 / [Issue #15](https://gitlab.com/11h27m/nexus-mobile/-/work_items/15)）。

原本（QGIS 由来 GeoJSON・実地調査 Excel）と明示的な対応設定から、
[`docs/schemas/map-dataset-geojson-v1.schema.json`](../../docs/schemas/map-dataset-geojson-v1.schema.json)
に適合する単一の `FeatureCollection` を決定的に生成し、検証レポートを出す。

**原本は読み取り専用。未確認値は推定せず、明示的な検証エラーにする。**
出力先に原本・対応設定・スキーマを指定した場合は実行前に停止する（symlink / ハードリンク含む）。
`publish_readiness` に blocker が残る間は既定で失敗し、暫定出力は `--allow-draft` のときだけ。

```bash
npm run mapdata:install          # 初回のみ（リポジトリルートから）
npm run mapdata -- --help
npm run mapdata:test
npm run mapdata:typecheck
```

使い方・入力契約・検証レポートの読み方・不足している実データ・E2-2 との責務境界は
[`docs/e1-6-map-dataset-conversion.md`](../../docs/e1-6-map-dataset-conversion.md) を参照。

| パス | 内容 |
|---|---|
| `map-dataset.mjs` | CLI エントリ |
| `src/` | 実装（設定読み込み、原本アダプター、geometry 正規化、座標変換、検証、パス衝突ガード、決定的シリアライズ、レポート） |
| `src/config.schema.json` | 対応設定の JSON Schema（正本） |
| `config/campus-buildings.config.json` | 実データ用の対応設定 |
| `../../map-data/` | 日付付き実測原本台帳と正規化済み入口座標。接続情報が揃うまで配布GeoJSONには含めない |
| `test/` | `node:test` による正常系・異常系テストと最小合成フィクスチャ |
