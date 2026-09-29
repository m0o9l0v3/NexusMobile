# Issue #77: MapDataset validator ユニットテスト

対象: `apps/admin-api-tests/MapDatasetValidatorTests.cs`（検証対象は #18 の `MapDatasetValidator`）。

## 方針

正本のサンプル `docs/schemas/examples/map-dataset-geojson-v1.example.json` を読み込み、1つの破損だけを加えた入力を検証にかける。fixtureを別ファイルとして複製しない。境界・許容値・Spot・変換結果は**テスト用の値**であり、現地測量や承認済み設定ではない。

## 期待結果と失敗判定基準

各ケースは「破損データが `CanPublish == false` になり、指定した `Code`（可能なものは `Path` と `CanonicalId` も）のエラーを含む」ことを期待する。次のいずれかならテスト失敗とする。

- 破損データが `CanPublish == true`、またはエラーなしで通る（見逃し）。
- 期待したコード以外でしか拒否されない（別の理由で偶然落ちている）。
- エラーの場所（JSON Pointer）や対象IDが異なる。
- 同じ入力で結果の内容・順序が変わる（非決定的）。

| 観点（Issue記載） | 主なテスト | 期待コード |
| --- | --- | --- |
| 参照切れ | `missing_reference` / `floor_building_missing` / `node_floor_missing` / `entrance_outside_missing` | `undefined_reference` |
| 重複 | `duplicate_feature` / `duplicate_floor` / `duplicate_edge` | `duplicate_canonical_id` / `duplicate_edge` |
| 孤立 | `isolation` | `isolated_node` |
| 到達不能 | 逆向き経路 / 別連結成分 / 入口Feature削除 | `unreachable_node`（孤立とは別に報告） |
| 座標範囲外 | `outside_world` / `latitude_out_of_range` / `outside_campus` / `path_partly_outside_campus` / `building_partly_outside_campus` | `schema_violation` / `outside_campus` |
| 形状破損 | ゼロ長経路 / 環の未閉鎖・自己交差 | `invalid_geometry` |
| 実行方針 | 出発ノード未指定 / draft検証 / 複数破損の同時報告 | `missing_validation_context` / draft でも `IsValid == false` / 全件報告・決定的順序 |

補足:

- ノードID・経路の端点種別（屋外/屋内）はJSON Schemaのパターンで固定されている。そのため種別違いの参照はスキーマ層で `schema_violation` になり、validatorの `reference_type_mismatch` には到達しない。この分岐は防御的な検査として残っており、現状の入力経路ではテストしていない。
- 出発ノードは呼び出し側が明示する。未指定の公開検証は推測せず拒否する。

## 実行

```sh
dotnet test apps/admin-api-tests/AdminApi.Tests.csproj --filter "FullyQualifiedName~MapDatasetValidatorTests"
```

2026-09-29 ローカル結果: `MapDatasetValidatorTests` 62/62件成功（#18時点の51件 + 本Issueの11件）。

実行環境の注意: この環境には .NET 8 ランタイムがなく、`DOTNET_ROLL_FORWARD=Major` で .NET 10 上で実行した。この場合、管理APIテスト全体では既存の `HealthEndpointTests` / `RateLimitingTests` の5件が `PipeWriter.UnflushedBytes` 例外で失敗する。変更前（stash）でも同じ5件が失敗し、本変更とは無関係。.NET 8 環境で全体を再確認すること。

## 範囲外

- validatorの合格は、現地の通行可否・アクセシビリティ・原データの正しさを保証しない。これらは現地確認で行い、validatorで代替しない。
- 本番データの検証や、実測値・承認済み設定の確定は含まない。
