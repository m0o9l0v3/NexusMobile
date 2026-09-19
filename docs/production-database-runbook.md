# 本番DBの構築・検証手順

採用方針は[本番データベースの採用・運用方針](decisions/production-database.md)。この手順は、VPSにログインできた後に実行するための手順書であり、VPSやAWSへの適用記録ではない。

## ローカル検証

Docker Engine / Compose、Python 3、.NET SDK 8を用意する。DockerはローカルのUnix socket接続先を明示する。Macでは専用Colimaプロファイルを使用できる。

```sh
colima start nexus-db-verify --cpu 2 --memory 4 --disk 20 --activate=false
DOCKER_CONTEXT=colima-nexus-db-verify python3 tools/database/verify.py
```

必要なら `DOTNET` / `DOCKER` / `COMPOSE` 環境変数に実行ファイルを指定する。`NUGET_PACKAGES` でキャッシュ保存先を指定できる。

検証処理はランダム名のComposeプロジェクト、ローカル限定の動的ポート、新規DB・volume・資格情報を使う。資格情報と生成SQL、APIログ、結果JSONはGit管理対象外の `.local/database-verification/` に保存する。成功時にはこの実行で作ったコンテナ・volumeを削除する。失敗時はコンテナを停止し、調査用にvolumeと記録を保持する。開発用・本番用の既存DBを入力する仕組みはない。

検証内容:

- 履歴が確認できない既存DBへの適用を、MapDataset表や移行履歴の作成前に拒否し、既存行を保持する。
- 空DBに完全な初期スキーマを作成し、SQLの再適用でも壊れないことを確認する。
- 実DBの全エンティティのカラム名・型・null許容とEFモデルを比較する。
- 公開API用ユーザーの未公開行・管理用表・将来追加表の読み取り、表更新・DDL・所有者への昇格が拒否されることを確認する。
- 公開APIの監査ログINSERTと、前回hashを読む連鎖処理を実サービス経由で確認する。
- MapDatasetのpayload/checksum、重複版、不正メタデータを検証する。
- 両APIをProductionモード・実行専用ユーザーで起動し、公開スポットのHTTP取得と起動前後のデータ件数を確認する。
- DB再起動後のデータ保持とSQL再適用を確認する。
- pgBackRestで暗号化フル・差分バックアップとWAL保存を行い、別volumeへ指定時点復旧する。復旧対象の版2が存在し、その後の版3が存在せず、元DBには版3が残ることを確認する。

ローカル試験のバックアップ保存先は隔離volume上のPOSIXリポジトリ。暗号化・WAL・PITRの実動作を検証するが、AWS S3通信・VPS障害時の復旧時間・15分/4時間の運用目標の達成までは検証しない。

## 初期スキーマの扱い

検出対象は既存の `20260905120000_AddMapDatasets` と、今回追加した `20260919120000_AddInitialPostgreSqlSchema`。後者は現行モデル全13表のうち、MapDataset以外の12表を追加する。既存の履歴ファイルを遡って有効化しない。新規SQLは元のMapDataset移行と合わせて必要な表を作る。

`InitialPostgreSqlSchema.sql` は現行EFモデルから生成したDDLを固定したもの。適用時にモデルから再生成しない。検証時に実DBとの全カラム比較を行う。過去の手動スキーマや別経路で作られたDBを自動的に採用する処理はない。

SQL出力はDBに接続しない。

```sh
dotnet build Nexus.sln
dotnet run --project tools/database/Nexus.Database.csproj --no-build -- script /tmp/nexus-migrate.sql
```

出力にはpsql向けのエラー停止設定、所有者ロールへの切替、セッション単位の排他ロック、既存スキーマ・未知の履歴の事前確認、EFの冪等SQLが含まれる。必ずこの出力経路を使う。直接の `dotnet ef database update` やアプリ通常起動によるDB更新は本番手順に含めない。

## VPSで最初に確認すること

1. OS、CPUアーキテクチャ、メモリ、ディスク容量、Docker/Composeの動作、時刻同期を確認する。
2. PostgreSQLプロセス、コンテナ、volume、既存DBがないかを読み取り専用で調べる。存在する場合、新規構築扱いで上書きせずスキーマ・履歴を照合する。
3. PostgreSQL 18.6以降の18系修正版、pgBackRest、APIイメージを検証し、VPSのCPU向けにビルドする。公開したレジストリのdigestを記録する。
4. S3東京リージョンの専用非公開バケットと最小権限の資格情報、復号キーのVPS外保管、失敗通知先を用意する。S3のバージョニング・保持設定は採用方針に合わせる。
5. 初回バックアップ、復元試験、通知到達の確認が完了するまで公開トラフィックを流さない。

## 本番の初期構築

本番用Composeは `deploy/database/compose.production.yml`。開発用Composeとは独立しており、DBの5432ポートを公開しない。APIはホストのloopbackにのみ公開し、HTTPSリバースプロキシから接続する。プロキシ・DNS・証明書の整備はVPS側の導入作業に含める。

1. `tools/database/prepare-secrets.py` で、リポジトリ外の新規ディレクトリへ資格情報を生成する。既存ディレクトリへの上書きは拒否される。ディレクトリは0700、秘密ファイルは0600。S3の `backup_s3_key` / `backup_s3_secret` は別途安全に配置する。
2. 設定ファイルに次を設定する。DBイメージは `deploy/database/Dockerfile` から構築したものを使う。設定値をシェルへ読み込む際はexportし、秘密の値をコマンド引数やログへ出さない。

| 設定 | 内容 |
| --- | --- |
| `NEXUS_POSTGRES_IMAGE` | 検証済みDB派生イメージの `repository@sha256:...` |
| `NEXUS_ADMIN_IMAGE` / `NEXUS_PUBLIC_IMAGE` | 検証済みAPIイメージのdigest参照 |
| `NEXUS_DB_VOLUME` | 新規作成・確認済みの本番専用外部volume名 |
| `NEXUS_SECRET_DIR` | 秘密ファイルを置いた絶対パス |
| `NEXUS_BACKUP_S3_BUCKET` | AWS S3東京リージョンの専用バケット |
| `NEXUS_ADMIN_ORIGIN` / `NEXUS_PUBLIC_ORIGIN` | 配信するHTTPSオリジン |

3. 外部volumeを明示的に作成し、`bash deploy/database/compose-production.sh config --quiet` で構成を検証する。続いて `up -d --wait postgres` でDBのみ起動する。
4. レビュー済みのSQLを移行専用ユーザーで適用する。同じ接続で所有者ロールへ切り替えて実行する。パスワードはコンテナ内で秘密ファイルから読む。

```sh
bash deploy/database/compose-production.sh exec -T postgres bash -c \
  'export PGPASSWORD="$(cat /run/secrets/migrator_password)"; exec psql -h 127.0.0.1 -U nexus_migrator -d nexus_admin -v ON_ERROR_STOP=1' \
  < /tmp/nexus-migrate.sql
{ printf 'SET ROLE nexus_owner;\n'; cat deploy/database/grant-runtime.sql; } | \
  bash deploy/database/compose-production.sh exec -T postgres bash -c \
  'export PGPASSWORD="$(cat /run/secrets/migrator_password)"; exec psql -h 127.0.0.1 -U nexus_migrator -d nexus_admin -v ON_ERROR_STOP=1'
```

5. `exec -T --user postgres postgres pgbackrest --stanza=nexus stanza-create`、同じ経路の `check`、`--type=full backup` を実行する。S3に正常保存され、復号キーで別volumeへ復元できることを確認する。
6. `up -d admin-api public-api` でAPIを起動する。専用ユーザー、非破壊の起動、公開・非公開の境界、ログINSERT、管理APIの認証を確認する。
7. 正式な初期データは原本を確認した別の投入作業で扱う。サンプルSpotやイベントは投入しない。

`compose-production.sh` はdigest参照を検査する。本番の外部volumeはComposeで削除しない。復元時は別の空volumeを準備し、検証後に切替先として指定する。`Down` による初期スキーマ削除はサポートしない。

## 更新・定期運用

- 新しいマイグレーション追加時は、SQL出力の既知履歴一覧と起動時検査、実DB検証、必要な実行権限を同時に更新する。APIには所有者権限を付けない。
- 週1回のフル、その他の日の差分バックアップをホストのsystemd timer等で実行する。実行コマンドは `compose-production.sh exec -T --user postgres postgres pgbackrest --stanza=nexus --type=full backup` / `--type=diff backup`。実行成功/失敗・所要時間を記録する。
- WAL転送はDB稼働中に継続する。初回stanza作成前やS3障害時には転送エラーが出るため、正常化確認と容量監視を必須にする。
- pgBackRestの `info --output=json` と `pg_stat_archiver` / 未転送WALを使って、採用方針の26時間/10分の通知基準を実装・試験する。通知先の設定と定期実行の設置はVPS側で実施する。
- 月1回、別volumeへの復元とPITR、API動作、移行履歴、MapDatasetの版/checksumを確認し、所要時間を記録する。
- スキーマ更新前はバックアップを確認してAPIを停止し、SQL適用、動作確認、API再開の順に進める。失敗時は自動Downを行わず、停止状態で原因確認または別volumeへの復旧を選ぶ。

## 現時点で未確認の項目

AWS S3実通信と資格情報・保持設定、VPSのリソース・公開経路・秘密ファイル、レジストリへのイメージ公開、定期ジョブ・監視通知、実データ量での負荷・復旧時間、本番データ投入は未実施。ローカル試験の成功を、これらの完了とみなさない。
