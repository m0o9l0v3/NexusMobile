# E0-8: `apps/nexus-ios` の CI を自己ホスト macOS ランナーで整備する

- 移行元ID: なし（新規） / 区分: E0 / 根拠: 2026-09-22 のリポジトリオーナーの判断
- 判断日: 2026-09-22
- 判断者: リポジトリオーナー（技術的意思決定者）
- 状態: 採用（ランナー登録は未実施、手順は本文書「導入手順」節を参照）

## 背景

[E0-6](E0-6-ios-client-of-record.md) により `apps/nexus-ios`（SwiftUI）が参加者向け iOS クライアントの正本と確定した。しかし静的確認の結果、次が判明した。

- `apps/nexus-ios` は Swift 80 ファイル、テスト 10 ファイル（`NexusTests/`、実行すると 86 テストケース）を持つ
- `Nexus.sln`（.NET ソリューション）には登録されていない（Swift プロジェクトのため対象外。ビルド単位は `Nexus.xcodeproj`）
- `.gitlab-ci.yml` にビルド・テストジョブが無い
- `.github/workflows/ci.yml` にもジョブが無く、かつこのファイル自体が接続先の GitHub リポジトリを持たない（`git remote -v` は `gitlab.com` のみ）。**死んだ設定ファイルであり、`.gitlab-ci.yml` との二重管理は実質発生していない**
- 結果として、このコードは一度も自動検証を通っていない。一方で撤去対象の `apps/mobile-ios` は `mobile-check` ジョブで検証され続けている（正本が未検証・撤去対象が検証され続けるという逆転状態）

## 検討した選択肢

macOS ビルドには macOS 実行環境（ランナー）が必要。次を比較した。

| 案 | 内容 | 却下・採用理由 |
|---|---|---|
| GitLab.com SaaS macOS ランナー | `saas-macos-medium-m1` 等のホスト型ランナー | 公式ドキュメント上 Premium/Ultimate プラン、または GitLab の Open Source Program（要 OSI 承認ライセンス）でのみ利用可能。本リポジトリは Free プランかつ LICENSE ファイルが無く OSP 対象外。Free プランでも技術的には使えるが、400分/月の共有 CI 時間を macOS 実行が 6〜12 倍消費するため実用的でない。**却下**（有料化は範囲外の判断） |
| GitHub Actions macOS ランナー | 新規に public GitHub リポジトリを作成しミラーし、`.github/workflows/ci.yml` でビルド | public リポジトリなら無料。ただし現状 GitHub 側にリポジトリが存在せず、新規作成・push mirroring 設定・シークレット二重管理という新しい運用が発生する。個人運営で GitLab Issue・MR 中心の運用を維持したい現状と合わず、**却下**（将来 GitHub 連携が別の理由で必要になった際に再検討） |
| GitLab Premium/Ultimate への課金 | SaaS macOS ランナーを使えるようにする | 費用が発生し、意思決定者の事前合意が必要な支出のため本Issueの範囲では**却下**（費用対効果が変われば再検討） |
| 自動化を諦め、README に手順を明文化するのみ | CI ジョブを追加しない | 検証が「実行し忘れる」形で属人化し、正本が未検証のまま放置されるリスクが残る。**却下**（ただし本採用案でもランナー未登録の間は実質この状態になるため、ローカル実行コマンドは README に明文化する） |
| **自己ホスト macOS ランナー（採用）** | リポジトリオーナー自身の Mac を GitLab Runner として登録し、`.gitlab-ci.yml` にジョブを追加 | 追加費用なし。既存の GitLab 中心の運用を変えない。欠点はランナーの可用性が「オーナーの Mac が起動して GitLab に接続しているか」に依存すること。この欠点は `when: manual` により吸収する（後述） |

## 採用方針

1. **`.gitlab-ci.yml` に `nexus-ios-check` ジョブを追加する。** タグ `macos` を持つ自己ホストランナーでのみ実行される。
2. **ジョブは `when: manual` とする。** 個人運営の Mac が常時 CI 用に起動しているとは限らないため、他ジョブの完了をブロックさせない。ランナーが起動していてビルドを検証したいタイミングでオーナーが手動実行する。
3. **`allow_failure: true` とする。** 手動実行かつランナーの可用性が不安定な導入初期において、このジョブの未実行・失敗が MR のパイプライン全体をブロックしないようにする。**ビルド・テストの成否そのものを無視してよいという意味ではない**。実行結果は `NexusTests` 86 件の成否として個別に確認すること。
4. **CI 構成の正本は `.gitlab-ci.yml` とする。** `.github/workflows/ci.yml` は接続先の GitHub リポジトリが存在しない死んだ設定であることを README に明記し、`nexus-ios-check` は追加しない。GitHub 連携を将来行う場合は、その時点で `.github/workflows/ci.yml` 全体の要否を別途判断する。
5. **ランナー未登録の間、`nexus-ios-check` は「登録済みだが実行できない」状態になる。** その間の検証は README 記載のローカルコマンド（`xcodebuild ... clean build` / `xcodebuild ... test`）で代替する。

## 導入手順（自己ホストランナーの登録）

**この手順はリポジトリオーナーが自身の Mac 上で実施する。** GitLab のランナー登録トークンは GitLab Web UI からのみ取得でき、書き込み権限を持たない自動化からは取得できない（本セッションで使用した `glab` の API トークンは読み取り専用であることを確認済み）。

1. GitLab で `https://gitlab.com/11h27m/nexus-mobile/-/settings/ci_cd` を開き、「Runners」→「New project runner」を選択する。
2. プラットフォーム `macOS`、タグに `macos` を指定して作成し、表示される登録用のコマンド（`glrt-` から始まるトークンを含む）を控える。
3. Mac に `gitlab-runner` をインストールする。

   ```bash
   brew install gitlab-runner
   ```

4. GitLab UI が提示するコマンド（例）でランナーを登録する。トークンは画面に表示されたものをそのまま使う。

   ```bash
   gitlab-runner register \
     --url https://gitlab.com \
     --token <GitLab UI が表示するトークン> \
     --executor shell \
     --tag-list macos \
     --description "nexus-ios macOS runner"
   ```

5. **登録後、GitLab の Runner 詳細画面で「Protected」を有効にする。** このリポジトリは public のため、保護されていないブランチ・fork からの MR パイプラインでもプロジェクトランナーが起動しうる。「Protected」を有効にすると保護ブランチ（`develop` 等）向けのパイプラインでのみ動作し、任意の外部 MR で自己ホストランナー上の任意コード実行を許すリスクを避けられる。
6. ランナーをサービスとして起動する（ログイン中のみで良い場合は `run`、常駐させる場合は `install` + `start`）。

   ```bash
   # 常駐させない場合（都度手動起動）
   gitlab-runner run

   # 常駐させる場合
   sudo gitlab-runner install
   sudo gitlab-runner start
   ```

7. GitLab の Runners 画面でランナーが `online` になっていることを確認する。以後、MR の `nexus-ios-check` ジョブを手動実行できる。

## 完了条件

- [x] `apps/nexus-ios` のビルドがローカルで再現できる（本Issue着手時に `xcodebuild -project Nexus.xcodeproj -scheme Nexus -destination 'platform=iOS Simulator,name=iPhone 17' clean build` で確認、`BUILD SUCCEEDED`）
- [x] `NexusTests` がローカルで再現できる（同上 `test` アクションで確認、86 テストケース全件成功）
- [x] `.gitlab-ci.yml` に `nexus-ios-check` ジョブを追加し、`.gitlab-ci.yml` を CI の正本と明確にした（`.github/workflows/ci.yml` は死んだ設定である旨を README に明記）
- [ ] 自己ホストランナーの登録（上記「導入手順」）。**リポジトリオーナーの実施待ち**
- [ ] 登録後、実際に `nexus-ios-check` を1回手動実行し、パイプラインが結果を出すことを確認する

## 却下した選択肢

「検討した選択肢」表を参照。

## 本Issueのスコープ外

- `apps/nexus-ios` 自体の機能実装（地図・位置情報・データ取得等）。E3〜E5 の各Issueの担当
- `apps/mobile-ios` の削除・撤去（[#87](https://gitlab.com/11h27m/nexus-mobile/-/work_items/87) の範囲）
- `.github/workflows/ci.yml` の削除・GitHub リポジトリとの連携有無の判断（将来 GitHub 連携が必要になった時点で別途判断）
