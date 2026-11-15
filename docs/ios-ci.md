# iOS CI の運用

[`ci.yml`](../.github/workflows/ci.yml) の `ios-xcode-test` は GitHub 管理の `macos-latest` でアプリのビルドとテストを実行する。対象は `main`・`develop` への push、fork を含む pull request、手動実行。公開リポジトリで標準の GitHub 管理ランナーを使う場合、実行は無料。 [GitHub Actions の料金](https://docs.github.com/en/actions/concepts/billing-and-usage)

- ジョブのログには macOS と Xcode のバージョン、選択した iPhone シミュレーターが出る。利用可能な iPhone 17 を優先し、なければ先頭の利用可能な iPhone を使う。
- ビルド出力は `$RUNNER_TEMP/DerivedData` に置く。失敗時に生成された `NexusTests.xcresult` は `nexus-ios-tests` アーティファクトとして 7 日間保存する。
- 公開リポジトリにはセルフホストランナーを登録しない。PR からワークフローの実行先を変更できるため、開発用 Mac への割り当ては GitHub 側で登録を解除して防ぐ。 [GitHub のセルフホストランナー利用ガイド](https://docs.github.com/en/actions/how-tos/manage-runners/self-hosted-runners/manage-access)

## 旧ランナーからの移行

1. 開発用 Mac のランナーインストール先で `./svc.sh stop` を実行する。GitHub の **Settings → Actions → Runners** で `nexus-ios` ラベルが付いたランナーを選び、**Remove** に表示される登録解除手順に従う。ランナー一覧から対象が消えたことを確認する。 [GitHub のランナー登録解除手順](https://docs.github.com/en/actions/how-tos/manage-runners/self-hosted-runners/remove-runners)
2. `macos-latest` への切り替えを含む PR を `develop` に反映する。反映までの間、旧設定で開発用 Mac を選ぶジョブは待機することがある。
3. `develop` への反映後、**Settings → Secrets and variables → Actions → Variables** からリポジトリ変数 `IOS_RUNNER` を削除する。
4. 通常の fork PR と `develop` への反映後のワークフロー実行を開き、それぞれの `ios-xcode-test` の **Set up job** ログで GitHub 管理の macOS イメージを確認する。テストまで完走し、ジョブが成功することを確認する。
