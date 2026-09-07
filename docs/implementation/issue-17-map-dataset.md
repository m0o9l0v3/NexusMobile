# Issue #17: MapDataset 保存基盤

## 実装範囲と受け入れ条件

前提は完了済み #14（E1-4）の GeoJSON スキーマ。新しい `MapDataset` と `AdminDbContext.MapDatasets`、追加専用マイグレーション、モデルスナップショットを実装する。

- GUID を内部主キー、正の `long` をデータ版とし、版の一意性を DB で保証する。
- `status` は `draft` / `published` / `archived` に限定する。作成時の既定値は `draft`。
- `payload` は GeoJSON FeatureCollection の文字列を `text` で保存し、メタデータを複製しない。
- `checksum` は保存する payload の UTF-8 バイト列の SHA-256、小文字16進64文字。DB は必須・長さを保証し、内容とハッシュの一致は後続の保存サービスが保証する。
- `published_at` は公開前には null、公開後には UTC の公開日時を保持する。
- 保存・再読込、重複版・不正メタデータの拒否、追加マイグレーションの再実行と既存データ保持を検証する。

## 判断理由と後続との境界

`jsonb` は空白・プロパティ順などを正規化するため、checksum の対象と保存後 payload の一致を単純に保てる `text` を採用した。これは SQLite / PostgreSQL 共通で扱える。データ版は payload の `nexus.schema_version` とは独立した単調増加番号として後続の作成APIで払い出す。現段階では公開版が一つという制約や status と公開日時の状態遷移制約を追加しない。publish/rollback のトランザクション設計は #20 の責務である。

GeoJSON 検証は #18、draft 作成・更新とchecksum計算は #19、公開・ロールバックは #20、公開配信は #23 が担当する。今回は HTTP エンドポイント・DTO・OpenAPI を変更せず、公開 API へ書き込みや管理データ公開を追加しない。

## マイグレーションと既存問題

`20260905120000_AddMapDatasets.Up` は `map_datasets` とその一意インデックスだけを作成する。既存テーブルの変更・削除・データ更新はない。`Down` はこの追加テーブルを削除する標準の逆操作なので、データが入った DB で実行すればデータを失う。本作業で既存 DB への Up / Down は実行していない。

既存マイグレーションには `Migration` / `DbContext` 属性がなく、対応する Designer も追跡されていない。このため、新しいマイグレーションを追加しても既存の初期スキーマ作成経路まで修復したことにはならない。過去の適用履歴を確認せず一括で検出可能にすると再実行の危険があるため、既存ファイルは変更していない。

既存 `DbSeeder.SeedAsync()` が SQLite 起動時に実行していた `EnsureDeletedAsync()` は、起動のたびに既存データを消すため削除した。SQLiteでは非破壊の `EnsureCreatedAsync()` のみを使い、再シード後も既存データが残ることをメモリ内SQLiteで検証する。ただし `EnsureCreatedAsync()` は既存DBへ追加マイグレーションを適用しないため、永続利用・本番導入の前に、既存DBとマイグレーション履歴に合わせた移行経路を別途整備する必要がある。

## 検証

実行すべきコマンド:

```sh
dotnet build Nexus.sln
dotnet test apps/admin-api-tests/AdminApi.Tests.csproj
dotnet test apps/public-api.Tests/PublicApi.Tests.csproj
git diff --check
```

追加テストは実際の SQLite マイグレーション・SQL制約を使用し、シーダー再実行時の既存データ保持も確認する。PostgreSQL は DB 接続不要のプロバイダーによる DDL 生成を確認する。実 PostgreSQL の既存DBに対する適用は別の確認事項。

ローカルでは .NET SDK 8.0.424 を用意したが、CLI のプロセス情報取得が `System.ComponentModel.Win32Exception` で失敗し、MSBuild 直接起動も `Process has exited` でビルド開始前に失敗した。変更前 develop と変更後で同じ環境エラーを確認した。GitLab CI の .NET 8 ジョブでビルドと両APIテストを検証する。ローカルの実行不能を成功として扱わない。

### CI 実行結果

[GitLab pipeline 2822768060](https://gitlab.com/11h27m/nexus-mobile/-/pipelines/2822768060) のコミット `73138c7b` で、`dotnet restore`、ソリューションbuild（警告0・エラー0）、管理API 23/23件（追加13件）、公開API 17/17件が成功した。ブランチ規則・public-api書き込みガード・mobile typecheck/lintも成功。詳細は[api-checkログ](https://gitlab.com/11h27m/nexus-mobile/-/jobs/16324487644)。
