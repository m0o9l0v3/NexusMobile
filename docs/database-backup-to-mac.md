# 追加契約なしのバックアップ：VPS内保存とMacへの取り出し

さくらVPS（石狩・RAM 4GB）上で暗号化バックアップを作り、既に使っているMacへSSHで取り出す。外部ストレージの契約・APIキーは不要。この文書は導入手順であり、実VPSへのSSH接続や設定が済んだことを意味しない。

VPS内の別volumeは、ディスク・VPS全体の故障に対する別拠点バックアップにはならない。VPSを失った際の復旧範囲は最後にMacへ保存できたコピーまで。Macが停止中・オフラインの間はコピーが更新されない。

## VPSでの準備（ログイン可能になった後）

1. [本番構築手順](production-database-runbook.md)に従い、DB用とバックアップ用の外部volumeを別の名前で用意する。同じVPSのディスクを消費するので、DB本体・5世代のフルバックアップ・差分・WALのための空き容量を確認する。
2. root所有・0600の `/etc/nexus/database.env` に構成値を保存する。`NEXUS_REPO_DIR` は配置したリポジトリの絶対パス。シェルへ読み込むファイルなので、管理者以外が変更できない場所に置く。イメージdigest、`NEXUS_DB_VOLUME`、`NEXUS_BACKUP_VOLUME`、`NEXUS_SECRET_DIR`、HTTPSオリジンも設定する。S3の項目は不要。
3. `deploy/database/backup-host.sh` をroot所有・0755の `/usr/local/sbin/nexus-backup-host` として設置する。リポジトリと `/etc/nexus/database.env` もroot管理とし、一般のSSHユーザーに書き換えさせない。
4. 初回はstanzaを作成し、`sudo /usr/local/sbin/nexus-backup-host check`、`sudo /usr/local/sbin/nexus-backup-host full` を実行する。既存stanzaを削除しない。
5. `deploy/database/systemd/nexus-db-backup.service` と `.timer` を `/etc/systemd/system/` へ設置し、`systemctl daemon-reload`、`systemctl enable --now nexus-db-backup.timer` で有効化する。毎日03:00 JST、日曜はフル、他の日は差分。未実行のまま停止していた場合は次の起動時に実行する。
6. `systemctl list-timers nexus-db-backup.timer` と `journalctl -u nexus-db-backup.service` で予定と結果を確認する。追加の通知サービスは契約せず、当面は毎日結果を確認する。既存の通知経路があれば後から接続する。

MacへダウンロードするSSHユーザーには、管理者が `sudo -n /usr/local/sbin/nexus-backup-host export` を実行できる権限を設定する。必要ならsudoersでこのコマンドと引数だけを許可する。スクリプトや参照設定が当該ユーザーから書き換え可能なまま権限を付与しない。

## Macへの保存

初回に次を準備する。

- SSHの接続名（例: `nexus-vps`）、鍵、ホスト鍵の照合を設定する。ツールは未登録・変更されたホスト鍵を自動承認しない。
- `backup_cipher` を安全な経路でMacにも保存し、0600にする。アーカイブ保存先と分け、Gitや会話へ貼らない。この鍵がないと復号できない。
- VPSと同じDBイメージのdigest・PostgreSQL/pgBackRestの版・CPUアーキテクチャ、Composeと秘密情報の復旧方法をMacへ保管する。物理バックアップは、Mac上でも元VPSと同じCPUアーキテクチャのLinuxコンテナで復元する。

Mac側で実行する例（接続名と鍵のパスは自分の設定に置き換える）:

```sh
python3 tools/database/download-backup.py nexus-vps \
  "$HOME/NexusBackups/$(date +%Y%m%d-%H%M%S)" \
  --key-file "$HOME/.nexus-backup/backup_cipher"
```

この処理はVPSで新しいフルバックアップを作成し、全保持世代とWALを含む暗号化済みリポジトリをtarとして転送する。圧縮済みのバックアップを読み出す方式で、DBの停止は不要。通常のバックアップ・世代整理と競合しないように待ち合わせ、転送中だけ新たなWALのリポジトリ書き込みを待たせる。その間のWALはDB側に蓄積するため、長時間転送や容量不足に注意し、無理な低空き容量で開始しない。

すべての手動バックアップも `nexus-backup-host` / `nexus-backup` を使う。コピー中に直接 `pgbackrest backup` / `expire` を実行したり、volumeを別のツールで変更したりしない。

成功時には `repository.tar`、SHA-256ファイル、`manifest.json` ができる。ファイルモードはtarが0600、保存先ディレクトリが0700。途中失敗・容量不足・切断時は `.partial` のままになり、保存完了の記録は作られない。再試行は別の新しい保存先で行う。既存コピーは上書きしない。

`manifest.json` の `downloaded_not_restore_verified` は「転送と構造確認は完了したが、復元確認はまだ」という意味。少なくとも利用日の1日1回と重要な更新の前後に保存し、直近3回以上の正常なコピーを残す。古いコピーを整理する前に新しいコピーの復元を確認する。

## Macにあるコピーだけから復元する

元VPSへ接続せず、保存したアーカイブ・別保管の鍵・記録済みのDBイメージを使う。Docker/Colimaを起動し、MacとVPSのCPUが異なる場合は記録したVPS側アーキテクチャのコンテナを実行できることを先に確認する。今回のローカル試験はARM64同士であり、実VPSのCPUとの組み合わせは導入時の確認対象。

1. 保存先で `shasum -a 256 -c repository.tar.sha256` を実行する。成功したコピーだけを使う。
2. 次の値を設定する。`NEXUS_RESTORE_IMAGE` は**バックアップ元と同じ検証済み派生イメージのdigest参照**。古いバックアップを新しいメジャー版で開かない。

```sh
export NEXUS_BACKUP_COPY_DIR="/absolute/path/to/downloaded-backup"
export NEXUS_BACKUP_CIPHER_FILE="/absolute/path/to/private/backup_cipher"
export NEXUS_RESTORE_IMAGE="registry.example/your-db-image@sha256:your-recorded-digest"
export NEXUS_RESTORE_PLATFORM="linux/amd64" # 実際のVPSがARM64ならlinux/arm64
RESTORE_PROJECT="nexus-restore-$(date +%Y%m%d-%H%M%S)"
```

3. `deploy/database/compose.restore.yml` を使い、毎回新しいプロジェクトで順に実行する。失敗した場合は次の段階へ進まない。

```sh
docker compose -p "$RESTORE_PROJECT" -f deploy/database/compose.restore.yml run --rm -T import &&
docker compose -p "$RESTORE_PROJECT" -f deploy/database/compose.restore.yml run --rm -T restore &&
docker compose -p "$RESTORE_PROJECT" -f deploy/database/compose.restore.yml up -d postgres
```

コピーは新しいbackup volumeに読み込まれ、DBも別の空volumeへ復元する。元のアーカイブはread-onlyでマウントし、ポートは公開しない。既に内容のある復元先への上書きは拒否する。

4. ログを確認し、復旧が完了したら、次の経路でSQLを実行する。

```sh
docker compose -p "$RESTORE_PROJECT" -f deploy/database/compose.restore.yml logs postgres
docker compose -p "$RESTORE_PROJECT" -f deploy/database/compose.restore.yml exec postgres \
  psql -U postgres -d nexus_admin -c 'SELECT pg_is_in_recovery(); SELECT version, status, checksum FROM map_datasets ORDER BY version;'
```

`pg_is_in_recovery()` がfalseになったこと、想定した版・件数、payloadのSHA-256とchecksum、移行履歴、必要なAPI動作を確認し、確認日時をMacの保存記録に残す。ダウンロード直後のmanifestは復元済みに自動変更されない。VPSへ戻す場合も、既存DBを消さず別volumeへ復元して確認後に切り替える。

最初の復元と月1回の復元を運用に組み込む。15分以内の損失や4時間以内の復旧はこの構成の保証値にしない。
