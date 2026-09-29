# Archived history

> This SDK-upgrade note applied to the Expo app `apps/mobile-ios/`, deleted on 2026-09-29. It is retained for history only; no Expo migration is active.

# Expo SDK 51 から SDK 54 への移行メモ

このリポジトリの現在の Git 管理対象には `apps/mobile-ios` や Expo の `package.json` / `app.json` / `metro.config.js` が含まれていません。そのため、このブランチ上では SDK 51 の依存関係ファイルを直接書き換える移行は実施できません。Expo アプリを追加または復元した後は、以下の手順で SDK 54 に合わせて更新してください。

## 1. Expo 本体を SDK 54 に固定する

```bash
cd apps/mobile-ios
npm install expo@~54.0.0
```

SDK 54 は React Native 0.81 / React 19.1 系のリリースです。手作業で `package.json` を編集するよりも、Expo が管理する互換バージョンへ揃えるために次のコマンドを必ず実行してください。

```bash
npx expo install --fix
npx expo-doctor
```

## 2. SDK 51 から段階的に検証する

Expo 公式は SDK のアップグレードを 1 バージョンずつ行うことを推奨しています。SDK 51 から一気に 54 へ上げる場合でも、問題の切り分けでは `51 -> 52 -> 53 -> 54` の差分を確認してください。

最低限の確認観点:

- `expo`, `react`, `react-native` が SDK 54 互換バージョンになっていること。
- Expo Router を使っている場合は SDK 54 対応の `expo-router` に更新されていること。
- `react-native-reanimated` を使っている場合は SDK 54 対応バージョンに更新し、必要に応じて `react-native-worklets` を追加すること。
- iOS / Android のネイティブディレクトリを保持している場合は、SDK 54 の Native Project Upgrade Helper に沿って差分を適用すること。

## 3. ネイティブ生成物を更新する

Continuous Native Generation を使っている場合は、古い SDK で生成された `ios` / `android` を再生成します。

```bash
rm -rf ios android
npx expo prebuild --clean
```

ネイティブディレクトリを手動管理している場合は、削除せずに SDK 54 の差分を手動適用し、iOS は Pod を更新します。

```bash
npx pod-install
```

## 4. Expo Go で起動確認する

Expo Go v54 は SDK 54 のプロジェクトを前提にしています。実機で確認する場合は、Metro の URL がスマホから到達できる LAN IP または Tunnel になっていることを確認してください。

```bash
npx expo start --clear --lan
# LAN で接続できない場合
npx expo start --clear --tunnel
```

## 5. このリポジトリへ Expo アプリを戻すときの注意

`apps/mobile-ios` を追加する場合は、少なくとも次のファイルを Git 管理対象に含めてください。

- `apps/mobile-ios/package.json`
- `apps/mobile-ios/package-lock.json` または利用中のロックファイル
- `apps/mobile-ios/app.json` または `apps/mobile-ios/app.config.ts`
- `apps/mobile-ios/metro.config.js`
- `apps/mobile-ios/babel.config.js`（利用している場合）

これらが揃えば、SDK 51 から SDK 54 への依存関係更新と設定ファイル更新をこのリポジトリ上で直接レビューできます。
