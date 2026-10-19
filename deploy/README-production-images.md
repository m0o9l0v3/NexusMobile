# 本番イメージの境界

GitLabの`public-api-image`、`admin-api-image`、`postgres-image`ジョブは従来のDR側経路として残る。同一repoのMRまたは既定ブランチでビルドし、GitLab Registryへcommit SHAタグでpushし、`image-digests/*.txt`に`registry/path@sha256:...`を記録する。PG17公開レイヤーのpublic-apiには、以下のGitHub Primary経路を使う。admin-api・postgresの発行方式は今回変更しない。イメージに本番secretを含めず、実行時にComposeの秘密ファイルを読む。

## public-apiのGHCR発行（DEC-2）

2026-10-19の発行先変更: 旧名`ghcr.io/m0o9l0v3/nexus-public-api`では、[初回ジョブ](https://github.com/m0o9l0v3/NexusMobile/actions/runs/39200756827)のAPIテスト・build・pushは成功したが、発行直後のprivate検査で失敗した。人間の画面確認でもPublic表示を確認した。公開に変わった経緯は未確定。ユーザー承認によりprivate方針を維持し、別名`ghcr.io/m0o9l0v3/nexus-public-api-pg17-private`へ切り替える。旧名への追加発行・削除・公開範囲変更はこの修正に含めない。旧ジョブは採用証跡の保存に到達していないため、そのイメージを採用済みとは扱わない。

新名に`private`が含まれていても、公開範囲は保証されない。再発行前に名前の利用可否を確認し、発行前後のprivate検査を維持する。既存Public版の扱いは別途判断し、Private版の発行だけで既存Public版の公開が解消したことにはしない。

`.github/workflows/public-api-image.yml`を`develop`または`main`から**手動実行**する。通常のpush・PRでは発行しない。入力はレビュー済みの完全なcommit SHAと、VPSの読み取り確認で確定した`linux/amd64`または`linux/arm64`。platformの既定値はなく、該当platformのGitHub-hosted runnerでnative buildする。該当runnerが利用できなければ停止し、勝手に別platformへ切り替えない。

初回実行前に人間が確認すること:

- GitHub Environment `public-api-image`を用意し、required reviewersと`develop`/`main`のbranch制限を設定する。手動入力のSHAがレビュー済みであることを承認者が確認する。workflow内でもintegration branchの履歴上にあることを検査するが、これはレビュー済みの証明ではない。
- `ghcr.io/m0o9l0v3/nexus-public-api-pg17-private`の名前・利用権限を確認する。初回発行はGHCRのprivate既定値を使う。既存packageはprivateでなければ発行を止め、visibilityは自動変更しない。404は未作成またはアクセス不可なので、権限不足なら発行を強行せず確認する。
- CIの発行にはjob単位の`GITHUB_TOKEN`（`contents: read`・`packages: write`、発行ジョブURLの取得に`actions: read`）を使う。VPS用PATをCIへ渡さない。

workflowは採用SHAを別checkoutに展開してAPIテストを実行し、public-apiだけをbuild/pushする。タグはcommit SHAだが、**採用する参照はbuild結果の`@sha256:`のみ**。BuildKit provenance（`mode=min`）・SBOMをregistryに付加し、`image-digests/public-api.txt`と`public-api.json`を90日間のActions成果物として保存する。JSONには採用commit・workflow commit・platform・run URL・発行job URL・attemptを記録する。インフラレビュー用に成果物を保全し、採用期間中はregistryのdigestとattestationを削除しない。90日を超える証跡の保全先・保持期間は運用側で確定する。digest固定は同じイメージを指定するもので、再buildの一致や実行時の安全性を保証しない。

VPSのprivate pull資格はPAT（classic）の`read:packages`のみ。発行アカウントのpackage読み取り権限、認証方針、必要ならSSO承認を確認する。VPSのroot用Docker設定またはそのcredential storeで保護し、tokenをGit・Issue・ログに残さない。発行・失効日、更新手順を私有運用メモで管理する。認証不能・platform不一致なら採用を止める。イメージ発行は本番デプロイ・DB変更を行わない。

仕様出典: [GitHub Container registry](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry)、[GitHubでのDocker image発行](https://docs.github.com/en/actions/tutorials/publish-packages/publish-docker-images)、[docker/build-push-action](https://github.com/docker/build-push-action)。

DBイメージはPostgreSQL 18とpgBackRestを含む。DB用とバックアップ用の外部volume、`/var/lib/postgresql`と`/backup`のマウント契約は`deploy/database/compose.production.yml`に従う。既存VPSのDB版・volume・データ配置が確認されるまでは適用しない。APIの通常起動は本番でDBの読み取り確認だけを行い、migrationとseedを実行しない。移行SQLはCI成果物としてレビューし、適用前バックアップ・Macコピー・別volume復元を確認した人間が別途適用する。
