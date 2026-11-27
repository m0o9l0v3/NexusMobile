# iOS アプリの実機ビルドと TestFlight

NexusMobile の iOS アプリ（`apps/nexus-ios/`）を、実機と TestFlight へ本番の接続先で出すための設定と手順。TestFlight の受入確認そのものは #87 で追う。

## 1. 決めたこと（2026-11-16）

| 項目 | 値 | 理由 |
|---|---|---|
| Bundle ID | `jp.nexus-app.mobile`（単体テストは `jp.nexus-app.mobile.Tests`、UI テストは `jp.nexus-app.mobile.UITests`） | オーナーのドメイン `nexus-app.jp` を逆にした形にした（オーナー決定）。旧 `dev.nexusapp.mobile` の `nexusapp.dev` は第三者のドメインである。ハイフンは Bundle ID で使える。なお旧 ID は Expo の頃にオーナーの有料のチームへ登録済みで、2026-11-16 の実機ビルドで登録できなかったのは、Xcode で別のチーム（個人のチーム）を選んでいたためと考えられる。旧 App ID は残しておく（消すと同じ ID を使い直せないことがある） |
| アプリ版・ビルド番号 | `MARKETING_VERSION = 1.0`、`CURRENT_PROJECT_VERSION = 1` | アプリターゲットの設定。配布時は生成した Info.plist と照合する |
| 最低 iOS | `IPHONEOS_DEPLOYMENT_TARGET = 18.0` | プロジェクトの `NEXUS_IOS_DEPLOYMENT_TARGET` を参照する |
| Release の接続先（`NexusAPIBaseURL`） | `https://api.nexus-app.jp` | 本番の配信エンドポイント（#23）。2026-11-16 に bundle 版 1 を配信中 |
| Debug の接続先 | 空（未接続）のまま | 開発中の起動・試験で本番へ通信しないため。scheme「Nexus」は検討用データを使い通信しない。本番で確かめるときは `Local.xcconfig` に書く |
| チーム ID | Git に入れない。`Config/Signing.xcconfig`（Git 対象外）に書く | 個人の Apple Developer の情報のため。CI は署名しない（`CODE_SIGNING_ALLOWED=NO`） |

App Store Connect にアプリを登録した後は Bundle ID を変えられない。変えるなら登録前に決め直す。

接続先は https なので App Transport Security の例外は要らない。アプリは App Group・Keychain の共有・独自の Capability を使っていないので、Bundle ID を変えても他の識別子は変わらない。位置情報は「使用中のみ」で、Capability の追加は要らない。

## 2. 設定ファイル

`apps/nexus-ios/Config/` に置く。

| ファイル | Git | 読む構成 | 書くこと |
|---|---|---|---|
| `Nexus.Debug.xcconfig` | 入れる | Debug | 接続先は空。`Signing.xcconfig` と `Local.xcconfig` を読む |
| `Nexus.Release.xcconfig` | 入れる | Release（Archive） | 本番の接続先。`Signing.xcconfig` だけを読む |
| `Signing.xcconfig` | **入れない** | Debug・Release | `NEXUS_DEVELOPMENT_TEAM`（チーム ID）だけ。`Signing.xcconfig.example` から作る |
| `Local.xcconfig` | **入れない** | Debug だけ | 手元の接続先、実機確認用の Bundle ID の上書き（任意）。`Local.xcconfig.example` から作る |

- Release は `Local.xcconfig` を読まないので、手元の接続先が TestFlight の版に混ざらない。
- `Signing.xcconfig` に Bundle ID や接続先を書かない（Release にも効いてしまう）。
- xcconfig は `//` から行末をコメントとして扱うため、URL は `https:/$()/api.nexus-app.jp` のように `//` を分けて書く。
- CI（`ios-release-config`）は Release を署名なしでビルドし、生成された Info.plist の `NexusAPIBaseURL` が `https://api.nexus-app.jp`、`CFBundleIdentifier` が `jp.nexus-app.mobile` であることを確かめる（M1-3）。

## 3. 初めての実機ビルド（Debug）

1. `cp apps/nexus-ios/Config/Signing.xcconfig.example apps/nexus-ios/Config/Signing.xcconfig` を実行し、`XXXXXXXXXX` を自分のチーム ID（Apple Developer の Membership details）に替える。有料の Apple Developer Program のチームを使う。個人のチーム（Personal Team）では TestFlight に出せず、App ID も有料のチームのものを使えない。
2. 本番の接続先で確かめるときは `Local.xcconfig.example` を `Local.xcconfig` に複製し、`NEXUS_API_BASE_URL = https:/$()/api.nexus-app.jp` にする。
3. Xcode で `apps/nexus-ios/Nexus.xcodeproj` を開き、scheme「Nexus API」、接続した iPhone を選んで実行する。Automatic signing が `jp.nexus-app.mobile` の App ID とプロファイルを作る。
4. `jp.nexus-app.mobile` を TestFlight の版と別に入れたいときは、`Local.xcconfig` で `NEXUS_PRODUCT_BUNDLE_IDENTIFIER = jp.nexus-app.mobile.dev` のように上書きする（Debug だけに効く）。

Xcode の Signing & Capabilities でチームを選ぶと `project.pbxproj` にチーム ID が書き込まれる。その変更はコミットしない（チームは `Signing.xcconfig` で渡す）。

## 4. TestFlight へ出す（オーナーの作業）

App Store Connect の記録、証明書、アカウントはオーナーが作る。

### 4.1 一度だけ

1. **Apple Developer → Certificates, Identifiers & Profiles → Identifiers** で、Explicit の App ID `jp.nexus-app.mobile` を登録する（説明は「Nexus」など）。Capability は追加しない。3章の実機ビルドで Xcode が作っていれば不要。
2. **App Store Connect → アプリ → ＋ → 新規 App**：
   - プラットフォーム：iOS
   - 名前：App Store に出す名前（他のアプリと重複できない。「Nexus」が使えなければ別の名前にする。ホーム画面の表示名 `Nexus` とは別に決められる）
   - プライマリ言語：日本語
   - バンドル ID：`jp.nexus-app.mobile`
   - SKU：任意の社内向けの文字列（例 `nexus-ios`）
   - ユーザアクセス：フルアクセス
3. **アプリアイコンを確認する。** [PR #210](https://github.com/m0o9l0v3/NexusMobile/pull/210)（`b05bb0d`）で Icon Composer 形式の [AppIcon.icon](../apps/nexus-ios/Nexus/Resources/AppIcon.icon) を設定済み。Release ビルドはアイコンを `Assets.car` に収録し、Info.plist に `CFBundleIconName = AppIcon` を出力する。オーナーが署名済み Archive をアップロードする際に、App Store Connect でアイコンの検証結果を確認する。

### 4.2 毎回

1. `develop` から出す版を決め、Mac で `Signing.xcconfig` があることを確かめる。
2. Xcode で scheme「Nexus」、出力先「Any iOS Device (arm64)」を選び、**Product → Archive**（Release で作られる）。
3. Organizer で **Distribute App → App Store Connect → Upload**。ビルド番号（`CURRENT_PROJECT_VERSION`、今は 1）は版ごとに増やす必要がある。Organizer の「Manage Version and Build Number」に任せるか、増やす PR を入れる。
4. App Store Connect の **TestFlight** でビルドの処理を待つ。輸出コンプライアンス（暗号化）については [`Config/Info.plist`](../apps/nexus-ios/Config/Info.plist) に `ITSAppUsesNonExemptEncryption = false` を設定済み（使用する暗号は OS 標準の HTTPS 通信 `URLSession` と整合性検証用 SHA-256 `CryptoKit` のみ）。
5. **内部テスト**のグループを作り、App Store Connect のユーザーをテスターに加える。端末に TestFlight アプリを入れて招待を受ける。
6. 外部テスター（App Store Connect のユーザーでない人）に配るときや App Store 審査へ出すときは、ベータ版 App 審査とプライバシーポリシー URL（`https://www.nexus-app.jp/privacy/`）が必要。公開サイト（`web/`）への `/privacy/` 反映は [`web-hosting.md`](web-hosting.md) を参照。

## 5. 関連

- App Store Connect 提出設定・掲載文案・審査メモ：[`app-store-submission.md`](app-store-submission.md)
- 接続先の注入の決定：[M1-3](decisions/M1-scope-and-interim-decisions.md)
- 受入・TestFlight 実機確認：[v1.0 統合試験の検証表・実施記録（#87）](verification/v1.0-integration-test.md)
- CI：[`ios-ci.md`](ios-ci.md)
