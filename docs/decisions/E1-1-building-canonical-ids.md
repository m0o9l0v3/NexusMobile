# E1-1: 建物14棟の canonical ID を定義する

- 移行元ID: E1-1 / 区分: E1 / 根拠: `Nexus_ID_Master_v2_draft.xlsx`（作業者手元の実地調査ドラフト、未リポジトリ化。Excel 3冊・GeoPackage・GitHub GeoJSON 由来の計130件のIDを棚卸ししたもので、部屋・廊下・出入口等スコープ外データを含むため、建物14棟分のみ本文書に転記する）
- 判断日: 2026-09-01
- 判断者: リポジトリオーナー（技術的意思決定者）

## 対象と調査結果

実地調査ドラフトの `ID_Registry` シートから、`entity_type=building` かつ `decision=keep`（最終確定）の14件を対象とする。QGIS GeoPackage由来の `building_<code>` プレフィックス付きID、GPS実測記録の未登録IDなど、同一建物を指す複数の生IDが `rename_now` として本来のcanonical IDへ統合されている。

| canonical_id | 表示名 | 却下された旧ID・表記 | 却下理由 | 備考 |
|---|---|---|---|---|
| `ab` | 管理棟（事務局を含む） | `building_ab` | QGIS GeoPackageのFeature ID命名（`building_`接頭辞）。R-002（短い固定コード方針）に反し冗長なため却下 | |
| `amh` | 女子寮（アメリアホール） | `building_amh` | 同上（`building_`接頭辞、R-002違反） | 境界点 `amh_bnd_001` が建物IDと混同されていた（C-001）。本文書では建物ID自体のみ確定 |
| `aptr` | 機体実習室 | `building_aptr` | 同上（`building_`接頭辞、R-002違反） | |
| `ar` | アリーナ | `building_ar`、GPS実測記録の未登録ID | `building_ar`はR-002違反で却下。GPS実測記録側の未登録IDは、GitHub GeoJSON・Excel実地調査データで既に`ar`として一致登録されているため、未登録のまま残す理由がなく`ar`へ統合 | |
| `ctc_main` | CTC | `building_ctc`、QGIS旧コード `ctc`（裸） | `building_ctc`はR-002違反。裸の`ctc`はGitHub GeoJSON・Excel実地調査データの現行ID`ctc_main`と不一致で、他ソースとの整合が取れないため却下（C-006） | |
| `ctc2` | CTC2 | `building_ctc2` | `building_`接頭辞、R-002違反のため却下 | |
| `dh` | 食堂 | `building_dr`、QGIS旧コード `dr` | `building_dr`はR-002違反。裸の`dr`は現行ID`dh`と不一致で、他ソースとの整合が取れないため却下（C-006） | |
| `dvh` | Da Vinci Hall | `building_dvh` | `building_`接頭辞、R-002違反のため却下 | |
| `hgr_a` | 格納庫A | なし（境界点IDとの混同のみ） | 境界点 `hgr_a_bnd_001` を建物ID代わりに使う運用は、建物IDと境界点IDの名前空間を分離する方針（C-001対応）に反するため却下 | |
| `hgr_b` | 格納庫B | なし（境界点IDとの混同のみ） | 境界点 `hgr_b_bnd_001` を建物ID代わりに使う運用は、同上の理由で却下 | |
| `lbh` | 男子寮（リンドバーグホール） | `building_dm`、QGIS旧コード `dm` | `building_dm`はR-002違反。裸の`dm`は現行ID`lbh`と不一致で、他ソースとの整合が取れないため却下（C-006） | 表示名表記揺れ（リンドバーグ/リンドバーク）は後続作業へ |
| `mb` | 教室棟 | `building_mb` | `building_`接頭辞、R-002違反のため却下 | 表示名表記揺れ（教室棟/本棟）は後続作業へ |
| `ptb` | 実習棟 | `building_ptb`（重複フィーチャ） | `building_`接頭辞、R-002違反に加え、GeoPackage上でconfirmed/provisionalの2フィーチャが同一IDを名乗る重複状態（C-007）であったため、provisional側は本番の14棟セットから除外 | confirmed feature が `ptb` を採用、provisional 重複は非本番IDへ退避（具体的置換IDは後続作業） |
| `sab` | 技能審査棟 | なし | 却下対象の旧ID・表記なし | |

## E1-1 判断時点の採用方針

**上記14棟の canonical ID をそのまま正式採用する。**

### 理由

- 実地調査ドラフトの `ID_Registry` シートにおいて、各建物は複数ソース（Excel実地調査データ、GPS実測記録、QGIS GeoPackage、GitHub上のGeoJSON）から確度 `high` で `keep`／`rename_now` と判定されており、追加の現地確認なしで確定可能な品質と評価した。
- 命名規則として lower_snake_case（`Naming_Rules` シート R-001）を採用し、建物IDは `building_` 接頭辞を使わない短い固定コードとする（R-002、良い例 `mb`/`ptb`/`ctc_main`、悪い例 `building_mb`）。QGIS由来の `building_<code>` 方式は冗長でこの方針に反するため不採用とする。
- C-001（建物IDと境界点IDの混同）への対応: 建物Featureのidは裸のID（`hgr_a` 等）を維持し、境界点は建物IDを再利用しない別名前空間（`{building}_bnd_{seq:03}`、R-006）とする方針をここに明記する。ただし境界点IDの採番自体はE1-1のスコープ外（E1-2以降）とし、本Issueでは「建物IDを境界点IDに流用しない」という原則のみを確定する。
- C-005（QGIS旧建物ID体系）／C-006（QGIS旧コード競合）への対応: GeoPackageのFeature ID・`code`列（`dm`/`dr`/`ctc`）はcanonical ID（`lbh`/`dh`/`ctc_main`）に置換する。QGIS側の`code`列を正式IDの根拠にはしない。
- C-007（`building_ptb` 重複）への対応: GeoPackageのconfirmed/provisional 2フィーチャのうち、confirmed側を正式 `ptb` として採用する。provisional側は本番の14棟セットに含めず、非本番／候補IDへ退避する。

### 却下した選択肢

- **`building_<code>` プレフィックス方式（QGIS legacy）を採用する**: 冗長であり、R-001（lower_snake_case）・R-002（短い固定コード）の方針に反する。却下。
- **QGIS旧コード（`dm`/`dr`/`ctc`）をそのまま canonical ID とする**: 現行ID（`lbh`/`dh`/`ctc_main`）と衝突し、他ソース（GitHub GeoJSON、Excel実地調査データ）との整合が取れない。却下。
- **`building_ptb` の重複を判断保留とする**: Issueの完了条件（後続Issueが追加確認なしで着手できる状態）を満たさないため却下。
- **表示名表記（教室棟/本棟、リンドバーグ/リンドバーク）を本Issueで即時確定する**: 学校公式資料での確認が取れておらず、この場での推測確定はリスクが高い。却下（保留し後続作業へ）。

## 後続作業（本Issueのスコープ外）

本Issueの完了条件は14棟のcanonical ID・命名規則の確定であり、表示名の最終確認や関連データの実装は別途対応する。

1. 表示名の正式確認（C-012）: `mb`（教室棟/本棟）、`lbh`（リンドバーグ/リンドバーク）の学校公式表記をリポジトリオーナーが確認し、確定後に本文書を更新する。canonical ID自体は表記に依存せず本Issueで確定済みのため、後続Issueはブロックされない。
2. `ptb` provisional 重複フィーチャの具体的な置換ID確定と、該当GeoPackageデータの修正（C-007の残作業）。
3. E1-2〜E1-7（階層ID、GeoJSONスキーマ、座標系、変換スクリプト、正式入口データ、部屋・廊下・出入口・境界点・道路・駐車場・ランドマークのID）は本Issueのスコープ外。実地調査ドラフトの `Naming_Rules` シート R-003〜R-014、`Conflicts` シートの非建物項目（C-002〜C-004, C-008〜C-011, C-013〜C-017）は将来の広範なID規約文書の参考資料として残るが、本Issueでは採用しない。

E1-2以降の後続Issueは、本文書の14棟canonical IDを前提として着手できる。
