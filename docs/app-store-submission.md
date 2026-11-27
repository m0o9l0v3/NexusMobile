# App Store Connect 提出・設定ガイド（v1.0）

`apps/nexus-ios/` を TestFlight 外部テストおよび App Store へ提出する際に使う、App Store Connect の設定値・ストア掲載文案・プライバシー回答・審査メモのまとめです。実機ビルドと Archive・アップロードの手順は [`ios-release.md`](ios-release.md)、統合試験と受入基準は [`verification/v1.0-integration-test.md`](verification/v1.0-integration-test.md) を参照してください。

---

## 1. App Store Connect 基本設定

| 項目 | 設定値・方針 | 備考 |
|---|---|---|
| プラットフォーム | iOS | iPhone のみ（`TARGETED_DEVICE_FAMILY = 1`、縦向き固定） |
| バンドル ID | `jp.nexus-app.mobile` | 登録後は変更不可 |
| プライマリ言語 | 日本語 | |
| SKU（任意） | `nexus-ios` | 社内管理用の識別子 |
| App Store 上のアプリ名 | 重複しない公開名を決めて先行確保する | 例：`Nexus 構内ガイド`、`Nexus オープンキャンパス` 等。「Nexus」単独は既存アプリと重複する可能性が高いため、ホーム画面名 `Nexus`（`CFBundleDisplayName`）とは別に設定する |
| カテゴリ | 主：ナビゲーション／副：教育 | |
| 価格 | 無料 | App 内課金なし |
| 年齢制限指定 | 4+ | アカウント機能・UGC・広告・アプリ内ブラウザなし（外部リンクは明示操作で OS 標準ブラウザへ遷移） |
| バージョン／ビルド番号 | `1.0` / `1` | アップロードごとにビルド番号（`CURRENT_PROJECT_VERSION`）を増やす |

---

## 2. ストア掲載文案（コピペ用下書き）

> 以下の文案は [v1.0 スコープ定義](v1.0-scope.md) に含まれる機能だけを書いています。v1.0 対象外の機能（屋内フロアマップ、リアルタイム混雑・待ち時間、QR チェックイン、時間割タブ）は含めないでください。

### サブタイトル（30 文字以内）

```text
オープンキャンパス構内案内マップ
```

### プロモーションテキスト（170 文字以内）

```text
オープンキャンパス当日の建物探しや移動をシンプルに。ホームで体験や施設を探し、マップで屋外の道順を確認。一度取得したデータは通信が不安定な場所でも見返せます。基本案内はオフラインでもすぐ読めます。
```

### 概要文

```text
Nexus は、日本航空大学校　北海道校　新千歳キャンパスのオープンキャンパス来場者向けの構内案内マップアプリです。
「ホーム」「マップ」「案内」の 3 つのタブで、当日の施設探しから移動、困ったときの基本案内までをわかりやすく確認できます。

主な機能：
■ ホームと検索
・開催日や体験・イベント一覧を日付・時間とともに確認できます。
・教室名・建物名・施設・サービスを、かな・英字・略称からまとめて探せます。
・受付・困ったとき・交通アクセスへすぐ開けるショートカットを備えています。

■ マップと屋外の道順
・構内の建物配置や地点詳細を屋外地図上で確認できます。
・現在地または自分で選んだ出発地（正門・駐車場など）から、目的地の建物入口までの屋外ルート・距離・徒歩の目安時間・曲がる地点のステップを表示します。
・位置情報の利用を許可しない場合でも、手動で出発地を選んで道順を確認できます。

■ オフラインでも安心
・受付、交通アクセス、学校生活、学生寮、よくある質問（FAQ）、体調不良時や迷ったときの案内をアプリ内に同梱しており、通信環境に関わらず閲覧できます。
・一度取得した地図・施設・イベントの公開データは端末内に保存（最終同期から 7 日間有効）され、通信が途切れても確認と経路の計算ができます。

※ 本アプリは屋外の建物入口までの道順を案内します（建物内のフロアマップは今後の版で順次対応予定です）。
※ 初回起動時の地図・イベントデータの取得にはインターネット接続が必要です。
```

### キーワード（100 文字以内）

```text
JAA,オープンキャンパス,キャンパス,構内地図,学内マップ,道案内,日本航空大学校,見学,大学校,施設検索
```

### URL・著作権

| 項目 | 値 |
|---|---|
| プライバシーポリシー URL | `https://www.nexus-app.jp/privacy/` |
| サポート URL | `https://www.nexus-app.jp/` |
| マーケティング URL（任意） | `https://www.nexus-app.jp/` |
| 著作権 | `© 2026 Nexus` |

---

## 3. App のプライバシー（栄養表示ラベル）回答ガイド

App Store Connect の「App のプライバシー」では、以下のとおり回答できます（[`PrivacyInfo.xcprivacy`](../apps/nexus-ios/Nexus/Resources/PrivacyInfo.xcprivacy) およびコード実装と一致しています）。

- **データの収集**：**「いいえ、この App からデータは収集されません」**
  - **位置情報**：使用中のみ端末内で地図表示と最寄り出発地の確認に利用し、Nexus のサーバーや第三者へ送信・保存しません（Apple の定義上、端末外へ送信しないオンデバイス処理は「収集」に該当しません）。
  - **連絡先・氏名・アカウント情報**：登録やログイン機能はなく、一切取得しません。
  - **利用状況ログ（`visit_logs`）・行動追跡**：v1.0 の iOS アプリからは送信しません。広告 SDK・外部アナリティクス SDK も未使用です。
  - **端末内キャッシュ・検索履歴**：オフライン閲覧と利便性のために端末内のみで保持し、外部へ送信しません。

---

## 4. 輸出コンプライアンス

- [`apps/nexus-ios/Config/Info.plist`](../apps/nexus-ios/Config/Info.plist) に `ITSAppUsesNonExemptEncryption = false` を設定済みです。
- 使用している暗号処理は、OS 標準の HTTPS 通信（`URLSession`）と配信バンドルの整合性検証用 SHA-256（`CryptoKit`）のみであり、輸出コンプライアンスの免除対象に該当します。

---

## 5. スクリーンショット要件

- **必須サイズ**：iPhone 6.9 インチ（例：iPhone 17 Pro Max / 16 Pro Max）または 6.5 インチ用を 1 セット以上用意します。
- **撮影タイミング**：**正式な構内地図・屋外経路データを本番公開した後**に、実機または同解像度シミュレーターで撮影してください。
- **推奨カット（4〜5 枚）**：
  1. **ホーム画面**：開催日・イベント一覧・検索バー・案内ショートカットが見える状態
  2. **マップ画面**：構内 14 棟と地点ピン・国土地理院の出典表記が見える状態
  3. **屋外経路案内**：建物入口までの経路ポリライン・距離／所要時間・ステップ一覧
  4. **施設検索または地点詳細**：検索結果と「経路を確認」導線
  5. **案内画面**：3 分類の案内一覧または案内記事（アクセス・FAQ など）

---

## 6. App Review Notes（審査メモ：英語・日本語）

Apple の審査員は大学構外（海外など）からアプリを操作します。位置情報だけに頼ると「構外です」表示になり経路案内を確認できないため、**手動出発地を使うテスト手順を審査メモに必ず記載**してください。

### 英語（App Store Connect の App Review Notes 欄に貼る文案）

```text
Thank you for reviewing Nexus.

1. Account / Sign-in:
No sign-in or account is required. All features are available immediately after launch.

2. How to test campus map & outdoor routing from outside the campus:
Because reviewers are located off-campus, please use the "Manual Origin" feature to test outdoor campus navigation:
(1) Launch the app with an internet connection to fetch the latest public campus dataset on the Home / Map tab.
(2) Open the "マップ" (Map) tab, or tap a building/spot from "ホーム" (Home) -> "マップで見る" (View on Map).
(3) Select any building or venue on campus and tap "経路を確認" (Check Route).
(4) Tap "出発地を選択" (Select Origin) and choose an on-campus outdoor starting point such as "正門" (Main Gate) or "駐車場" (Parking).
(5) The app calculates the outdoor walking route on-device and displays the route polyline, distance, estimated walking time, and turn-by-turn steps.

3. Location Privacy:
Location permission ("While Using the App") is optional and used strictly on-device to show the user's position on the campus map and suggest the nearest starting point. Location data is never transmitted to our servers or third parties. Users who deny location permission can still use the full route guidance via manual origin selection.

4. Map Data & Authorization:
This app is an official open-campus guide provided with permission from the school. Building outlines and road edges incorporate Geospatial Information Authority of Japan (GSI) Fundamental Geospatial Data under Surveying Act Article 30 approval (administered through the school's administrative office).
```

### 日本語参考訳

- ログインは不要で、起動後すぐに全機能を利用できます。
- 構外から経路案内を試す場合は、マップ画面（またはホームから「マップで見る」）で任意の施設を選び、「経路を確認」→「出発地を選択」から「正門」や「駐車場」などの構内出発地を選択することで、経路ポリライン・距離・所要時間・ステップ案内を確認できます。
- 位置情報は使用中のみ端末内で利用し、サーバーや第三者へ送信しません。位置情報を許可しない場合も手動出発地で全機能を利用できます。
- 学校の許可のもと提供するオープンキャンパス案内アプリであり、地図データは測量法第 30 条に基づく国土地理院の承認を得て作成・利用しています（手続きは学校事務局が管理）。

---

## 7. 審査提出前の最終ゲートチェックリスト

1. **地図・経路データの確定と本番公開（最大ブロッカー）**
   - [ ] 構内 14 棟・入口・屋外歩行ネットワークの現地測量を実施し、正式データを生成する（[#26](https://github.com/m0o9l0v3/NexusMobile/issues/26)・[#32](https://github.com/m0o9l0v3/NexusMobile/issues/32)・[#33](https://github.com/m0o9l0v3/NexusMobile/issues/33)）。
   - [ ] NexusStudio から正式な地図・屋外経路・14 棟の説明文（U-2）・開催日／イベントを `https://api.nexus-app.jp` へ公開し、審査時に API が空状態にならないようにする。
   - [ ] 学校事務局から測量法第 30 条の承認番号通知を受領したら、[`GSIAttribution.swift`](../apps/nexus-ios/Nexus/Shared/Models/GSIAttribution.swift) の `approvalNumber` と [`building-provenance.csv`](../map-data/normalized/building-provenance.csv) へ転記する（B16）。
2. **公開サイトの反映**
   - [ ] `/privacy/` を含む最新の `web/` ビルドを本番（`https://www.nexus-app.jp/privacy/`）へデプロイし、スマホ／PC・ライト／ダークで表示を確認する（[`web-hosting.md`](web-hosting.md)）。
3. **実機検証と運用確認**
   - [ ] 実機での GPS 精度・位置権限・電池消費の計測（[#80](https://github.com/m0o9l0v3/NexusMobile/issues/80) / B20）を完了し、`LocationAcquisitionSettings` の本採用値を確定する。
   - [ ] TestFlight 配布および段階 B 統合試験（[#78](https://github.com/m0o9l0v3/NexusMobile/issues/78)・[#79](https://github.com/m0o9l0v3/NexusMobile/issues/79)・[#87](https://github.com/m0o9l0v3/NexusMobile/issues/87)）を完了する。
   - [ ] E8 本番運用・セキュリティ証跡を最終突合する（[`v1.0-integration-test.md`](verification/v1.0-integration-test.md) §6）。
4. **リリース判定・審査提出・公開後更新**
   - [ ] 正式地図反映後のスクリーンショットを撮影し、App Store Connect のメタデータを確定する。
   - [ ] [#82](https://github.com/m0o9l0v3/NexusMobile/issues/82) に v1.0 リリース判定を記録し、App Store Connect から審査へ提出する。
   - [ ] App Store 公開後、[`web/src/pages/top.tsx`](../web/src/pages/top.tsx) の `appStoreUrl` と `web/public/app-shots/hero-light.png` を差し替えて公開サイトを更新する。
