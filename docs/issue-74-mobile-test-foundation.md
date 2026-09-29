# Archived history

> This document describes the retired Expo/Jest test setup for `apps/mobile-ios/`, deleted on 2026-09-29. The current iOS test target is `apps/nexus-ios/NexusTests/`, run by the `ios-xcode-test` GitHub Actions job. Keep this file as historical evidence; do not use its commands for current iOS work.

# #74 mobile-ios のテスト基盤

対象: [Work item #74](https://gitlab.com/11h27m/nexus-mobile/-/work_items/74)。依存先 E0-1 (#3) の GitLab CI が整備済みであることを前提とする。

## 要求と受入条件

Issue は `No tests yet` を実際のテストランナーに置き換え、CI に組み込むことを要求している。完了条件は「概要に記載した観点を再現可能なテストまたは手順として整備する。期待結果と失敗時の判定基準を明記し、実行結果を確認する」。本変更では次のように具体化した。

| 受入条件 | 検証方法・期待結果 | 失敗の判定 |
|---|---|---|
| ローカルで実際のテストを実行できる | `npm test` で TypeScript / TSX のテストを実行 | テスト未検出・assertion失敗・変換失敗は非0終了 |
| CIで同じテストを実行する | GitLab / GitHub の `mobile-check` に `npm run test:ci` を追加 | Jestの非0終了がジョブへ伝わる。`allow_failure` や `continue-on-error` は付けない |
| 既存の正常系と異常系を保護する | 下記3スイート、17テストが成功 | 期待する表示・返却値・コールバック・エラー伝播と異なる場合は失敗 |
| 既存開発フローを壊さない | clean `npm ci`、typecheck、lint、iOS JS export | コマンドの非0終了 |

## ランナー選定と構成

- Jest 29 + `jest-expo/ios` を使用。既存の Expo SDK 54 / React Native 0.81.5 と一致する `jest-expo` 54 系に限定する。Native API のモックは Expo preset に任せる。
- React Native Testing Library 13.3.3 で実際の検索コンポーネントを描画し、文字入力・選択・表示を検証する。13系および `jest-expo` 54 が使う `react-test-renderer` はアプリの React と同じ `19.1.0` に完全固定する。React / Expo を更新するときはこの組合せも見直す。
- 代替の Vitest / Node test runner は純粋関数には使えるが、React Native の Flow / TSX 変換と Native モックを別途整える必要がある。現行Expo presetを使用するほうが設定と保守を小さくできる。RNTL14への移行は依存構成の変更を伴うため、このSDK54向け基盤とは分ける。
- `babel-preset-expo` を直接の開発依存にし、Expo標準の `babel.config.js` を明示する。このリポジトリではpresetがExpo配下にネストされており、Jestの初回実行でFlow構文を変換できなかったため。Metroにも従来のExpo標準presetを使用する。
- テストはExpo Routerの `app/` 配下へ置かず、`apps/mobile-ios/__tests__/` に置く。テストはルートとして登録されない。
- 実APIへ接続しない。APIテストは `fetch` だけを置換して、本物のイベント変換処理を通す。各テスト後に環境変数と `fetch` を復元し、時刻テストには明示した日時を渡す。

参考: [Expo: Unit testing](https://docs.expo.dev/develop/unit-testing/)、[Expo Router: Testing](https://docs.expo.dev/router/reference/testing/)、採用パッケージの `peerDependencies` と `expo/bundledNativeModules.json`。

## テスト対象

| ファイル | ケース数 | 保護する振る舞い |
|---|---:|---|
| `events-api.test.ts` | 6 | URL末尾スラッシュ、API情報の変換・補足、欠損情報と不正日時、開発用URLと空配列、HTTP失敗、接続失敗、JSON解析失敗 |
| `open-campus.test.ts` | 7 | 開始直前・開始時刻・終了直前・終了時刻、次のイベント判定、時刻不明と入力配列の不変性、注目イベント選択と空配列 |
| `map-search-overlay.test.tsx` | 4 | 非表示状態、現在地の候補除外、タグ検索の空白/大小文字、選択通知と閉じる通知、空結果から入力クリアによる復帰 |

画面全体のsnapshotや描画成功だけのテストは追加していない。全機能・全画面の網羅を意味するものではない。

## 再現手順

リポジトリ直下から実行する。CIと同じNode 20系（React Nativeの要求を満たす20.19.4以降）を使用する。

```bash
cd apps/mobile-ios
npm ci
npm run typecheck
npm run lint
npm test
npm run test:ci
```

開発中に変更を追跡する場合は `npm run test:watch` を使用する。CIモードはwatchを使わず、worker数による環境差を避けるため直列実行する。テスト未検出を成功扱いにする `--passWithNoTests` は使用しない。

iOS向けJavaScript / Hermes bundleのビルド確認（ネイティブアプリのビルドではない）:

```bash
CI=1 EXPO_OFFLINE=1 npx expo export --platform ios --output-dir /tmp/nexus-ios-export --max-workers 2
```

失敗伝播を再現する場合、`open-campus.test.ts` の開始時刻 `10:00` の期待値を一時的に `live` から `ended` に変更し、次を実行する。1件失敗・終了コード1になることを確認し、期待値を元に戻して全テストを再実行する。変更した期待値はコミットしない。

```bash
npm run test:ci -- --runTestsByPath __tests__/open-campus.test.ts
```

## 実行結果とレビュー

2026-09-05、Linux上で確認。

- 変更前: `npm ci`、typecheck、lint成功。`npm test` は `No tests yet` を出力するだけだった。
- 変更後: clean `npm ci` 成功。Node 24.19.0およびCIと同じメジャーのNode 20.20.2で `npm run test:ci` が3スイート/17テスト成功、typecheck / lintも成功。
- 意図的な期待値不一致: 7件中1件失敗、`npm run test:ci` の終了コード1を確認。元の期待値に復元済み。
- iOS export: Node 24 / 20の両方で1,100 modules、Hermes bundle約2.78 MBの生成成功。
- diffレビュー: 製品のTS/TSX実装・UI文言・API契約は変更していない。CI変更はmobile-checkに1ステップ追加のみ。lockfile更新には新規テスト依存と、`jest-expo` の要求による `@expo/config` 12.0.13→12.0.14、`@expo/config-plugins` 54.0.4→54.0.5のpatch更新が含まれる。主要なReact/React Native/Expoのバージョン変更はない。

## 既存問題・残存リスク・人間の確認

- 検索コンポーネントがReact Native本体の `SafeAreaView` を使っており、実際の描画テストで非推奨警告が出る。警告を抑制せず記録し、UI変更はこのIssueに含めない。
- npm依存には既存およびテストツール由来の非推奨警告がある。メジャー更新はこのIssueの範囲外。
- Native APIはモックのため、iPhoneのSafe Area、キーボード、タップ領域、実際の地図・ルーター連携、実ネットワーク接続は保証しない。macOS + Xcodeのネイティブビルドと実機確認は別途必要。
- このローカル記録はGitLab Runnerでの実行結果を代替しない。MRの `mobile-check` 完了を確認する。v1.0全体のE9完了や実機テスト完了を意味しない。
