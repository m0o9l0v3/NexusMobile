# 本番イメージの境界

`public-api-image`、`admin-api-image`、`postgres-image`のCIジョブは同一repoのMRまたは既定ブランチでビルドし、GitLab Registryへcommit SHAタグでpushする。各ジョブの`image-digests/*.txt`成果物には不変の`registry/path@sha256:...`を記録する。インフラMRはタグではなく、このdigestを照合してから採用する。イメージに本番secretを含めず、実行時にComposeの秘密ファイルを読む。

DBイメージはPostgreSQL 18とpgBackRestを含む。DB用とバックアップ用の外部volume、`/var/lib/postgresql`と`/backup`のマウント契約は`deploy/database/compose.production.yml`に従う。既存VPSのDB版・volume・データ配置が確認されるまでは適用しない。APIの通常起動は本番でDBの読み取り確認だけを行い、migrationとseedを実行しない。移行SQLはCI成果物としてレビューし、適用前バックアップ・Macコピー・別volume復元を確認した人間が別途適用する。
