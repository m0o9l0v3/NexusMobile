# iOS CI を開発者の Mac（self-hosted runner）で実行する

`ci.yml` の `ios-xcode-check` / `ios-xcode-test` は、リポジトリ変数 `IOS_RUNNER` で実行先を切り替える。

| `IOS_RUNNER` | 実行先 |
|---|---|
| 未設定 / `self-hosted` 以外 | GitHub-hosted `macos-latest`（従来どおり） |
| `self-hosted` | ラベル `self-hosted, macOS, ARM64, nexus-ios` を持つ runner（オーナーの MacBook Air） |

`self-hosted` でも、**fork からの `pull_request` は常に `macos-latest` で実行する**。このリポジトリは public なので、fork の PR を self-hosted で動かすと第三者のコードが手元の Mac 上で実行されるため。

## 判断の記録

- 採用理由: GitHub-hosted macOS は無料枠の消費が大きく（Linux の 10 倍換算）、待ち時間も長い。手元の Mac（Apple M4 / Xcode 27）は普段の開発環境と同じ Xcode で検証できる。
- 代替案:
  - `macos-latest` のまま使う（現状維持。Mac がオフラインでも CI が止まらない）。
  - Tart などで Mac 上に使い捨て VM を立てて runner を動かす（隔離は強いが、構成と保守の負荷が大きいので今回は見送り）。
- 既知の制約:
  - Mac がスリープ・オフラインの間、iOS ジョブは待機し続ける（最大 24 時間でキャンセル）。長期間使えないときは `IOS_RUNNER` を削除して `macos-latest` に戻す。
  - 同時実行は 1 ジョブ。push と pull_request が重なると順番待ちになる。
  - ジョブは runner を起動したユーザー権限で動く。キーチェーンやホームディレクトリにアクセスできるため、専用の macOS ユーザーで動かすのがより安全。

## セットアップ手順

### 1. runner を登録する（Mac で実行）

GitHub の **Settings → Actions → Runners → New self-hosted runner**（macOS / ARM64）に表示される手順でも同じことができる。ここでは `gh` で登録トークンを取得する。

```bash
mkdir -p ~/actions-runner && cd ~/actions-runner
curl -fsSLO https://github.com/actions/runner/releases/download/v2.338.0/actions-runner-osx-arm64-2.338.0.tar.gz
echo "df4cebda25c86a886ed204e49fee63f5c2e7cec5f447b5c98440a826bbdf9df2  actions-runner-osx-arm64-2.338.0.tar.gz" | shasum -a 256 -c
tar xzf actions-runner-osx-arm64-2.338.0.tar.gz
./config.sh --url https://github.com/m0o9l0v3/NexusMobile \
  --token "$(gh api -X POST repos/m0o9l0v3/NexusMobile/actions/runners/registration-token --jq .token)" \
  --name "$(scutil --get LocalHostName)" --labels nexus-ios --unattended
```

バージョンとハッシュは [actions/runner のリリース](https://github.com/actions/runner/releases) で最新を確認する。runner は起動後に自動更新される。

### 2. 常駐させる

```bash
cd ~/actions-runner && ./svc.sh install && ./svc.sh start
```

LaunchAgent としてログイン中に常駐する。一時的に動かすだけなら `./run.sh`。

### 3. CI を切り替える

```bash
gh variable set IOS_RUNNER --body self-hosted --repo m0o9l0v3/NexusMobile
```

戻すとき: `gh variable delete IOS_RUNNER --repo m0o9l0v3/NexusMobile`

### 4. リポジトリ設定を確認する

**Settings → Actions → General → Fork pull request workflows** を「Require approval for all external contributors」にする（現在は first-time contributors のみ）。ワークフロー側でも fork PR は self-hosted に回さないが、二重の防御として設定する。

## 運用メモ

- ビルド成果物は `$RUNNER_TEMP/DerivedData` に置き、普段の Xcode の DerivedData と混ざらないようにしている（ジョブごとに消える）。
- Xcode を更新したら `xcodebuild -version` で CI のログと一致しているか確認する。シミュレーターは `ios-xcode-test` が利用可能な iPhone を自動選択する。
- runner を外すとき: `./svc.sh stop && ./svc.sh uninstall && ./config.sh remove --token "$(gh api -X POST repos/m0o9l0v3/NexusMobile/actions/runners/remove-token --jq .token)"`
