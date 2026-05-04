# mobile-ios

## 起動

```bash
cd apps/mobile-ios
npm install
npm run start
```

iOS シミュレーター（macOS + Xcode 必須）:

```bash
npm run ios
```

## API接続

`EXPO_PUBLIC_API_BASE_URL` を設定してください。

- iOS Simulator: `http://127.0.0.1:5001` など
- 実機: `http://<PCのLAN IP>:5001`
