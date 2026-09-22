# Issue #18: MapDataset validator

## 実装と責務

`apps/admin-api/Services/MapValidation/MapDatasetValidator.cs` に、DB書き込み・ネットワーク通信を行わない検証サービスを追加した。管理APIのDIへSingletonで登録する。#19のdraft APIから呼ぶための基盤であり、本変更でHTTPエンドポイント・公開処理・alias用DBテーブルは追加しない。

前提となる#17はMR !11で実装済みだが、2026-09-22時点でdevelopへ未統合。本ブランチは#17と最新developを含む。別ブランチ `codex/production-db-foundation` の本番構築・追加契約なしバックアップとは独立した変更として扱う。

## スキーマの正本

`docs/schemas/map-dataset-geojson-v1.schema.json` をビルド時に管理APIへ埋め込み、JsonSchema.Net 9.4.0 / Draft 2020-12で評価する。スキーマを別のC#定義へ手作業で複製せず、実行時の外部スキーマ取得も行わない。JSONキーの重複、無効なJSON、有限値でない数値、8MiBを超える入力も拒否する。

Polygonの妥当性はNetTopologySuite 2.6.0で確認する。自己交差・穴の配置・閉鎖・退化などの判定と、外環/内環の向きの判定を行う。NTSの経緯度平面上のLengthをメートルとして使用しない。

API用Dockerfileはリポジトリルートをビルドコンテキストとし、必要なAPIコードとスキーマだけをコピーする。`.dockerignore` でローカル検証情報・秘密ファイル・DB・ビルド成果物をコンテキストから除外する。ルートおよび `docker/` のComposeもこの構成へ更新した。

公開APIのpublishでは、参照先AdminApiのappsettingsが公開API自身のappsettingsと衝突していたため、参照先ホストの設定だけをpublish対象から除外する。公開API自身の設定ファイルは保持する。

## 呼び出しと結果

```csharp
var result = validator.Validate(payload, context, cancellationToken);
```

- `Errors`: `Code`、JSON Pointer形式の`Path`、`Message`、対象の`CanonicalId`を持つ。context由来の場所は `/context/...` と表す。
- `IsValid`: 今回要求された検証でエラーがなかったこと。
- `CanPublish`: `context.ForPublication == true` かつエラーなしの場合だけtrue。draft検証成功を公開判定へ流用しない。
- 結果は場所・エラーコード・IDで決定的に並べる。入力payloadは変更しない。
- `context`省略時はdraft検証。空のfloors/featuresを許容し、`CanPublish`は必ずfalse。

`CanPublish`はこのサービスの検査を通過したことを表す。認可、現在の版・競合、トランザクション、現地の通行可否を保証するものではない。#20の公開処理はそれらを別途確認する。

## 検証範囲

| 項目 | 動作 |
| --- | --- |
| JSON Schema | 必須・型・列挙・ID形式・geometry・2次元・経緯度の範囲・未知フィールドを検証 |
| canonical ID | Featureとfloor全体の重複を検出。Ordinal完全一致で扱う |
| 参照と所属 | 建物・フロア・内外ノードの存在、種別、親子関係、ID接頭辞を検証 |
| 経路 | 自己ループ、端点不一致、同方向の重複辺を検出 |
| 接続性 | 接続辺のないノードを孤立として報告。明示的な出発ノードから有向BFSで到達不能を検出 |
| 正式入口 | 内外ノードの接続を双方向の論理接続として扱う。通行可否やアクセシビリティは推測しない |
| 形状 | Polygonの不正形状・向き、ゼロ長LineString、小数6桁を超える座標を検出 |
| キャンパス範囲 | callerが渡す承認済みPolygonが各geometry全体を覆うことを確認 |
| 距離・時間 | 明示ENU原点でWGS84 ECEFから同一局所平面へ射影し距離を比較。所要時間は元データの値と照合 |
| 座標変換 | フロアごとの検証結果がE1-5の0.05m / RMS 2m / fit最大3m / check最大3m / 丸め0.10m以下か確認 |
| Spot/nav | 公開DB Spot.Codeと公開ナビSpotDto.Idの対応を双方向に検証。大文字小文字違いも不一致 |
| alias | 重複、全canonical IDとの衝突、参照先Spot不在、Spot.Codeを介したalias chainを検出 |

同じ実体のMapDataset ID・Spot.Code・ナビIDの一致は重複エラーにしない。異なるDB行が同じSpot.Codeを持つ場合は拒否する。未公開Spotが他のdraftの予約済みcanonical IDを参照することは許容し、他の予約済みIDもaliasとの衝突検査へ含める。

## 公開判定に必要なcontext

以下はサーバー側の信頼できるスナップショット・承認済み設定から構成する。HTTP利用者の申告値をそのまま信用して公開条件を満たしたことにしない。未提供と「確認済みの空配列」を区別する。

- `StartNodeIds`: 明示した出発ノード。先頭ノードや全入口を自動的に出発点へしない。
- `CampusBoundaryGeoJson`: 承認されたCRS84 Polygonの許容範囲。
- `EnuOrigin`: 距離比較用の基準原点。
- `EntranceMaxGapMetres` / `PathDistanceToleranceMetres`: 承認された距離の許容値。既定の実測値を捏造しない。
- `ExpectedPathSeconds`: 各経路の元データに基づく所要時間。
- `FloorTransforms`: 各フロアの変換検証結果。ここでは集計値を照合し、原測量・アンカー推定を実行しない。
- `DatabaseSpots` / `PublishedNavigationSpotIds` / `Aliases` / `OtherReservedCanonicalIds`: 整合した時点のIDスナップショット。

これらが欠ける公開要求は `missing_validation_context` / `missing_transform_evidence` 等で拒否する。現在の原本に未確定のノードや接続があること、キャンパス範囲・入口距離の許容値・正式な移行表の承認が必要なことは、この実装で解消した扱いにしない。

aliasの入力は採用済み方針に合わせ、`AliasCode`と参照先の`SpotId`（GUID）。別aliasへ向けるAPIやresolverは追加しない。入力スナップショットの参照先Spot.Codeがaliasに一致する破損状態をchainとして検出する。

## 検証

`MapDatasetValidatorTests` に51ケースを追加。正本のサンプルJSONを読み、各破損条件を独立して作る。境界・距離許容値・Spot・alias・変換結果は**テスト用の値**であり、本番の実測値や承認済み設定ではない。

正常系、空draft、JSON破損/重複キー、参照切れ、重複ID/辺、親子不一致、孤立、孤立ではない別連結成分、逆向き経路、座標範囲・次元・精度、環の破損、キャンパス範囲、入口距離、経路距離/時間、IDスナップショット、E1-5各上限超過、context欠落、並行呼び出し、キャンセルを確認した。

2026-09-22ローカル結果: 管理API **84/84件**、公開API **17/17件**成功。ソリューションビルドは警告0・エラー0。

```sh
dotnet test apps/admin-api-tests/AdminApi.Tests.csproj
dotnet test apps/public-api.Tests/PublicApi.Tests.csproj
docker build -f apps/admin-api/Dockerfile -t nexus-admin-validator .
docker build -f apps/public-api/Dockerfile -t nexus-public-validator .
```

## 次の工程

1. #17と本変更のレビュー・統合。
2. #19でdraft作成・更新・検証APIへ組み込む。結果形式のHTTP契約とOpenAPIを同時に整える。
3. #21/#57の担当範囲と連携し、実DB・公開ナビ・aliasの正しいスナップショットを供給する。
4. 未確定の現地データ・設定・移行表を確認し、正式データで検証する。コードやfixtureの合格を正式データ移行完了の根拠にしない。
