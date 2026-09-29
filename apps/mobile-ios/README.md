# 旧 Expo アプリ（apps/mobile-ios）

このディレクトリは、SwiftUI への移行前に使っていた Expo / React Native 実装を、[#30](https://github.com/m0o9l0v3/NexusMobile/issues/30) と [#87](https://github.com/m0o9l0v3/NexusMobile/issues/87) の整理条件が満たされるまで保全する場所です。現行 iOS アプリは [`apps/nexus-ios/`](../nexus-ios/) の SwiftUI プロジェクトです。

既存 Expo 画面や設定は旧実装の調査・比較時だけ使ってください。現行アプリのビルド・実行・テスト手順は [`apps/nexus-ios/Nexus.xcodeproj`](../nexus-ios/Nexus.xcodeproj) とリポジトリの README を参照してください。

## 旧実装を一時起動する場合

```bash
npm install
npm run start
npm run ios
```

旧 Expo アプリの API 接続には `EXPO_PUBLIC_API_BASE_URL` を使います。これは SwiftUI アプリの設定ではありません。
