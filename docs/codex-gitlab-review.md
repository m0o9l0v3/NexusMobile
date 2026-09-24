# CodexのGitLabネイティブMRレビュー

GitLabの`ai-review` CIジョブはOpenAI Responses APIの個別キーとGitLab書込トークンを必要とする独自実装だった。必要なCI変数が未登録でも成功扱いでスキップするため、レビュー済みと誤解しやすかった。この方式は廃止し、Codex CloudのGitLab連携によるコードレビューを使う。

## NexusMobileの現状（2026-09-24確認）

- Codex CloudのGitLabコネクターは`11h27m`として接続済み。
- `11h27m/nexus-mobile`のCodex Cloud環境が存在し、GitLabアクティビティが有効。
- GitLabプロジェクトWebhookはMR・noteイベントをCodexへ送信し、直近の配信はHTTP 200。
- Codexの個人設定で自動レビューがオン。NexusMobileは個人設定に従い、トリガーはMR作成時。

## 利用方法

- 新しいMRを作成するとき、自動レビューを受けたい場合はレビュー可能な状態で開く。Draftで作成し後でReadyにしたMRは、作成時トリガーだけではレビューが保証されない。
- 既存MRやDraft MRでは、GitLabのMRコメントに`@codex review`を投稿して手動レビューを依頼する。Codexの👀リアクションとレビュー投稿を確認する。反応がなければCodex Cloudの環境・コードレビュー設定とGitLab WebhookのRecent eventsを確認する。
- 自動レビューはCIジョブではない。GitLabパイプラインが緑色でも、Codexのレビューが行われたとは判定しない。マージ前にGitLabのMRレビュー欄を人間が確認する。
- リポジトリ固有の観点はルートまたは対象ディレクトリの`AGENTS.md`の`## Code Review Rules`に記載する。

設定と手順の原典: https://learn.chatgpt.com/docs/third-party/gitlab
