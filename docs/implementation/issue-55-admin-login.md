# Issue #55: 管理ポータルのログインと認証ガード

## 要求と受け入れ条件

依存Issueなし。既存 `POST /admin/auth/login` と `login()` を利用し、手動トークン挿入が不要な管理画面を提供する。

| 条件 | 期待結果 |
|---|---|
| 未認証で保護ルートを開く | Layout・管理ナビを表示せず `/login` へ移動 |
| 正しいログイン応答 | `accessToken` を保存し、元の管理画面へ戻る |
| ログイン失敗・通信失敗・壊れた応答 | 日本語エラー、パスワード消去、再試行可能。管理画面へ入らない |
| 送信中 | 多重送信と入力を防ぐ |
| 期限切れ・不正な保存トークン・APIの401 | セッションとQueryキャッシュをクリアしログインへ戻る |
| 403 | 認可エラーとしてセッションを維持する |
| 古いリクエストの401 | その後に確立された新しいセッションを消さない |
| ログアウト・別タブでのログアウト | 保護画面を閉じ、戻る操作で再表示しない |
| 戻り先 | 許可した管理ルートだけへ戻し、外部URLやloginへのループを拒否 |

## 実装と判断

- `Login`、`RequireAuth`、セッション購読を追加する。既存Router/Layoutと日本語UI、44px以上の入力・ボタン領域を維持する。
- トークン保管は既存の `localStorage.adminToken` 契約を維持する。HttpOnly Cookie等への変更は #56 の設計判断であり、今回APIやインフラを変えない。
- クライアントでJWTのexpを確認するのは表示と期限切れ制御のため。署名・role・失効の認証認可は既存Admin APIの責務のまま。
- ログアウトはブラウザのセッション終了。発行済みJWTのサーバー側一括失効を追加しない。
- API共通fetchでBearerヘッダーと401を扱い、URL/initとRequest双方のヘッダー・本文を保持する。既存QR画像fetchも同じセッション処理を使うが、新しいQR画面や公開導線は追加しない。
- Queryキャッシュはログイン・ログアウト・別タブのセッション切替で破棄する。
- React Routerは既知のオープンリダイレクト指摘を含む6.30.3から7.18.3へ更新する。Vite設定が利用するNode型も直接依存として固定し、CI環境の間接依存に頼らない。

## 再現可能な検証

```sh
npm ci
npm run typecheck --workspace apps/admin-web
npm run build --workspace apps/admin-web
npm run lint --workspace apps/admin-web
npx playwright install chromium
npm test --workspace apps/admin-web
```

Playwright 1.62.1を固定し、CIは同じ版の公式イメージを利用する。ブラウザとパッケージの版を同時更新する。[公式Docker手順](https://playwright.dev/docs/docker)に従い、ブラウザ導入済みイメージで再現性を確保する。`admin-web-check` は型チェック・ビルド・17テストを実行し、失敗を許容しない。失敗時のtraceは7日保存する。テストは偽の資格情報とモックAPIだけを使う。

17テストはJWT/戻り先の単体2件とブラウザ15件。API成功・認証拒否・ネットワーク失敗・無効JSON・トークン欠損/失効、全保護ルート、期限境界、複数タブ、403、遅延401を検証する。期待値不一致やブラウザ起動失敗は非0終了になる。

## 実行結果と既存問題

- 変更前 `55280af`: typecheck・build成功。既存Viteプラグイン非推奨と500KB超チャンク警告あり。
- 変更後: 最新`develop`（MR !12）を統合した状態でtypecheck・build成功。同じ既存警告を確認。
- `npm run lint`: 終了0だが `lint not configured` を表示するだけ。実際のlint成功とは扱わない。
- ローカルChromeで単体2件・ブラウザ15件の計17件が成功。GitLab CIでは引き続きブラウザ導入済みのPlaywright公式イメージを使う。
- `tar`をrootの7.5.13とmobileの7.5.16から7.5.22へ更新し、両監査のCriticalを1件から0件にした。rootは9件（low 2 / moderate 1 / high 6）、mobileは33件（moderate 19 / high 14）が残るため、Expo SDK等の互換性検証を伴う更新は別変更で扱う。
- 生成されたdist/tsbuildinfoは本変更に含めず、lockfileの無関係なパッケージ更新を除去した。

既存管理ナビにhidden betaのQR導線が残る点、Dashboardなどがモックである点、settings/events等のPlaceholderは既存の別Issueであり、今回のログイン実装でv1.0正式公開の対象に昇格しない。

## 残存リスクと人間の確認

実API・配備先のCORS・実際の管理アカウントでの接続確認は別途必要。ブラウザテストのAPI応答はモックであり、本番認証情報は使用していない。localStorageのXSS耐性と保管方式は #56 で扱う。ログイン画面の実ブラウザでの視覚確認、パスワードマネージャとの操作感もレビュー対象。

## 初回CIで見つけたテストの前提不備

初回CIは15件成功・2件失敗。戻る操作のテストはreplace遷移しかなくブラウザ初期ページへ戻っていたため、事前に別の保護画面へ遷移して履歴を作成するよう修正した。期限境界テストは画面読込中にテスト時計が進んでいたため、読込前に時計を停止してから境界の9,999ms/1msを進めるようにした。期待結果を弱めずに再実行する。
