# map-validation-legacy（一時的な退避先）

admin-api の削除（[E8-7 r1](../../docs/decisions/E8-7-r1-admin-api-removal.md)、PR-b）で、admin-api にあった
`MapDatasetValidator`（`MapValidation/`）と #77 のテスト（`MapDatasetValidatorTests.cs`）をここへ移した。
中身は変えていない（名前空間も `AdminApi.Services.MapValidation` のまま）。

## なぜ残すか

地図の正本は NexusStudio にあり、Studio に同じ validator とテストがある（E2-5 v2 §8.1）。§8.1 は
「Studio のテストとの突合後に削除する」としているが、PR-b の時点で突合は済んでいない。そこで D-6 に従い、
突合が終わるまでの間だけ、どのイメージにも入らないこのテストプロジェクトとして動かし続ける。

2026-11-14 にテストメソッド名だけを比べたところ、次の5つは Studio
（`apps/studio-api-tests/MapDatasetValidatorTests.cs`、develop `165d468`）に同じ名前のテストが無い。
名前が違うだけで同じことを確かめているかは、まだ確かめていない。

- `BrokenFixtures_ReportReferenceGeometryAndRangeFindingsAtTheirLocation`（`floor_building_missing` などの場所の報告）
- `DraftValidation_RejectsBrokenReferencesButNeverPublishes`
- `PublicationWithoutStartNodes_IsRejectedInsteadOfGuessingAStart`
- `RemovedFormalEntrance_LeavesIndoorNodesUnreachableButNotIsolated`
- `SeveralDefects_AreAllReportedInOneRunInDeterministicOrder`

## 削除する条件

突合の結果を #77 に記録し、Studio 側で同等の検査が担保されていると確かめたら、このフォルダと
`Nexus.sln`・CI の登録を消す。

```bash
dotnet test tools/map-validation-legacy/MapValidationLegacy.Tests.csproj
```
