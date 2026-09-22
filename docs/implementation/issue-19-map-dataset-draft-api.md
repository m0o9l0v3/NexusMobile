# Issue #19: MapDataset draft API

## 実装範囲

管理者認証が必要な `admin/map-datasets/drafts` 配下へ、draft の作成・更新・保存前検証 API を追加した。

| Method | Path | 動作 |
| --- | --- | --- |
| `POST` | `/admin/map-datasets/drafts` | draft 検証に合格した payload を、全状態を通した次の版番号で保存する |
| `PUT` | `/admin/map-datasets/drafts/{id}` | `draft` 状態の payload だけを置換し、checksum を再計算する |
| `POST` | `/admin/map-datasets/drafts/validate` | payload を保存せず draft 検証し、構造化した結果を返す |

request の `payload` は GeoJSON を格納した JSON 文字列とする。保存時に文字列を整形・再シリアライズせず、その UTF-8 バイト列から SHA-256 の小文字16進 checksum を計算する。このため、空白・改行・日本語を含む入力と checksum の対応が保存前後で変わらない。

## 検証契約

作成・更新・検証はいずれも #18 の `MapDatasetValidator` を publication context なしで呼ぶ。draft では空の `floors` / `features` を許容する一方、JSON破損、スキーマ違反、参照切れ、ID重複、孤立ノードなどは許容しない。

- 検証専用 API は検証処理を完了できた場合、finding の有無にかかわらず `200` を返す。
- 作成・更新では finding がある payload を保存せず、`422` と `isValid` / `canPublish` / `errors` を返す。
- draft API は公開用の信頼済み context を受け取らず、`canPublish` は常に `false`。公開判定と状態遷移は #20 の責務とする。
- published / archived の更新は `409` で拒否し、#20 の状態遷移を迂回しない。
- 存在しない更新対象は `404`、版番号上限または同時作成による版払い出し競合は `409` とする。

`packages/openapi/admin.yaml` に上記3 endpoint、request / response、validation finding の schema と主要な応答を追加した。

## 版番号と同時作成

新規 draft の版は `map_datasets` 全体（draft / published / archived）で最大の版に1を加えて払い出す。最大版の読み取りと保存は serializable transaction で行い、一意制約または直列化競合が発生した場合は、誤って別の版を上書きせず `409` で再試行を求める。

## 検証

`MapDatasetDraftsControllerTests` で以下を確認する。

- 保存済みの全状態を通した次版の払い出し。
- payload を書き換えない保存と SHA-256 checksum の一致。
- 不正JSONの構造化結果、作成拒否、更新時の既存データ維持。
- 更新時の版・状態維持と checksum 再計算。
- published 更新、存在しないID、版番号上限の異常系。

ローカル環境は .NET 8 runtime がなく .NET 10 runtime のみのため、テスト実行時に `DOTNET_ROLL_FORWARD=Major` を指定した。実装対象は引き続き `net8.0` でビルドしている。

```sh
DOTNET_ROLL_FORWARD=Major dotnet test Nexus.sln --no-restore
```

本作業では実DBへの migration、正式データの投入、publish / rollback、公開配信は実行していない。
