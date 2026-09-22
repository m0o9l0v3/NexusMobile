# Nexus iOS ネイティブ移行計画

> **後続決定による更新（2026-09-22）:** 本書は**承認済み**である。SwiftUI への移行は
> [Work item #82](https://gitlab.com/11h27m/nexus-mobile/-/work_items/82) 以下として
> 2026-09-07 に発行され、[E0-6](decisions/E0-6-ios-client-of-record.md) により
> `apps/nexus-ios` が参加者向け iOS クライアントの正本として確定した。
> 本書を通常の文書導線から外す扱いは解除する。
>
> ただし**本文のうち次の2点は現状と一致しない。該当箇所は下記を正とする。**
>
> 1. **タブ構成**: 本文の「Home / Map / 時間割 / 情報」は、
>    [E6-1](decisions/E6-1-tab-structure.md) の **ホーム / マップ / 案内 / 探す** に置き換わった。
>    「時間割」に相当するタブは設けない。
> 2. **初回リリース境界**: 本文は「Home のみ移植し、他タブは準備中表示」を前提とするが、
>    実装は4タブ分の UI と注入境界まで進んでいる。一方でデータ取得・地図・経路は未接続であり、
>    E3〜E5 はほとんど未実装である（[E0-6](decisions/E0-6-ios-client-of-record.md) の実装状態を参照）。
>    v1.0 の必須成果は [`docs/v1.0-scope.md`](v1.0-scope.md) を正とする。
>
> 本書の 4 章「現行スコープ文書との関係」が求めていた `docs/v1.0-scope.md` の同期は、
> 2026-09-22 に実施済みである。5〜12 章の移植方針・実装ルール・テスト移行は引き続き有効。

- 初版: 2026-09-07 ／ 状態更新: 2026-09-22（承認済み）
- 対象: 参加者向け Nexus iOS クライアント（`apps/nexus-ios`）
- 目標構成: SwiftUI + Swift のネイティブ iOS アプリ
- タブ構成: ホーム / マップ / 案内 / 探す（[E6-1](decisions/E6-1-tab-structure.md)）

## 1. 結論

React Native から SwiftUI へ移植するのは、完成に近い Home 画面と、その Home を成立させる最小限のデータ取得・表示ロジックだけとする。

Map、時間割、情報は既存実装を移植しない。初回リリースではタブと静的な「準備中」画面だけを用意し、既存の画面、component、mock、検索、経路、センサー連携などは、完成度にかかわらず Swift 側へ引き継がず廃棄する。

1. `apps/nexus-ios` に本番用 SwiftUI アプリを新設する。
2. Home だけを既存 React Native 実装から移植する。
3. App shell は Home / Map / 時間割 / 情報の4タブとする。
4. Map / 時間割 / 情報は共通の `ComingSoonView` を表示する。
5. Home から未実装機能へ向かう操作は、合意した準備中表示へ遷移させる。
6. Home の受入確認後、既存の Map / 時間割 / 情報実装を削除する。
7. SwiftUI 版の本番切り替え後、Expo / React Native アプリ全体を削除する。

既存コード量や完成度を理由に、非 Home 機能を初回リリースへ戻さない。

## 2. 初回リリースの製品境界

| 画面 | 初回リリース | 実装内容 |
|---|---|---|
| Home | 提供 | 今日の案内、確認項目、クイックアクセス、ヘルプ導線 |
| Map | 準備中 | アイコン、タイトル、短い説明だけの静的画面 |
| 時間割 | 準備中 | アイコン、タイトル、短い説明だけの静的画面 |
| 情報 | 準備中 | アイコン、タイトル、短い説明だけの静的画面 |

準備中画面には、次を実装しない。

- API 呼び出し、mock data、cache
- 検索、filter、詳細画面
- deep link や route parameter の仮実装
- 位置情報、MapKit、CoreMotion、センサー権限
- 将来機能を先取りした state、model、repository

「準備中」は、機能が存在しないことを利用者へ明確に示す静的状態とする。

## 3. 実装前の Design Gate

Home は React Native 画面をそのまま写経せず、Figma で再構築してから SwiftUI へ実装する。ここで visual polish だけでなく、初回リリースの情報優先度と準備中画面への導線を確定する。

### 3.1 Figma で作成するもの

- Home の通常画面
- Home の loading / event なし / 通信失敗状態
- Map / 時間割 / 情報の準備中画面
- Home / Map / 時間割 / 情報の4タブ navigation
- Home card、status pill、section header、quick access card の component
- semantic color、spacing、corner radius、type style の variables
- 標準文字サイズと大きな Dynamic Type の代表 frame

Figma では iOS の semantic color、SF Symbols、Auto Layout、reusable component を優先する。SwiftUI 側も Figma の座標を写すのではなく、`ScrollView`、`TabView`、system spacing と小さな subview で再現する。

### 3.2 対話で決める必要がある事項

次は既存コードだけでは一意に決められないため、Figma の比較案を見ながら合意する。

1. 4タブの順序と正式名称
   - 推奨初期案: Home / Map / 時間割 / 情報
2. Home の「今日の案内」を API 連携したまま残すか、固定案内にするか
   - 推奨: `/api/events/today` を Home のためだけに残す
3. 「今日確認してほしいこと」を全項目残すか、絞るか
4. クイックアクセスの項目数と並び順
5. 未実装機能を押したとき、対応タブへ移動するか、Home 上で準備中 sheet を出すか
   - 推奨: 対応タブへ移動する
6. 準備中画面に公開予定時期を表示するか
   - 日程未確定なら表示しない
7. 学校名、イベント名、受付案内を正式文言として確定できるか
8. light mode のみか、dark mode も初回から対応するか
9. 最小 iOS version と対象 iPhone size
10. 既存 Figma file を更新するか、新しい iOS native file を作るか

回答が揃う前でも、既存 Home を基準に low-fidelity frame と比較案までは作成できる。SwiftUI 実装を変える項目は Design Gate を通過するまで確定扱いにしない。

### 3.3 Design Gate の完了条件

- Home の通常・loading・empty・error が Figma 上で確認できる。
- 準備中3画面と4タブ構成が確認できる。
- component と token が再利用可能な形で定義されている。
- 未確定事項が decision log に残り、実装へ影響する項目は合意済みである。
- SwiftUI の受入 checklist が Figma frame と対応している。

## 4. 現行スコープ文書との関係

> **解決済み（2026-09-22）:** 本章が求めていた Work item への記録と文書の同期は完了した。
> SwiftUI 移行は [#82](https://gitlab.com/11h27m/nexus-mobile/-/work_items/82) 以下として
> 2026-09-07 に発行され、`docs/v1.0-scope.md` は 2026-09-22 に
> [E0-6](decisions/E0-6-ios-client-of-record.md)・[E6-1](decisions/E6-1-tab-structure.md) を反映した。
>
> **ただし採用されたのは「Home-only への縮小」ではない。** v1.0 の必須成果（Map、施設検索、
> 屋外・屋内地図、経路案内、案内コンテンツ）は維持したまま、実装先を `apps/nexus-ios` に、
> タブ構成を4タブに変更した。下記の2案はいずれも採用していない。

現行 `docs/v1.0-scope.md` では、Map、施設検索、屋外・屋内地図、経路案内、Info などが v1.0 の必須成果になっている。このままでは Home-only リリースを v1.0 完了として扱えない。

実装前に、今回の方針を GitLab Work item へ記録し、次のどちらかに正式変更する。

- 初回リリースを Home-only MVP として v1.0 より前に定義する。
- v1.0 を Home-only + 準備中画面へ縮小し、Map / 時間割 / 情報を後続版へ移す。

少なくとも次の文書を同じ変更単位で更新する。

- `docs/v1.0-scope.md` … **2026-09-22 に更新済み**
- `README.md` … **2026-09-22 に更新済み**
- `docs/overview.md`
- `docs/design-rules.md`
- `docs/mobile-sensor-integration-plan.md`
- E1〜E6、E9 のうち Map / 経路 / Info / センサーを初回リリース前提にしている文書

Web 廃止、iOS first、Android later の方針は維持する。`apps/admin-web` は参加者向け Web ではないため、本計画の削除対象に含めない（**`apps/admin-web` の排除は [E0-7](decisions/E0-7-studio-scope-split.md) で別途決定された**）。

## 5. 移植する Home の範囲

### 5.1 表示

`apps/mobile-ios/src/components/HomeScreen.tsx` から、次を Figma で再設計したうえで SwiftUI へ移す。

- ブランドヘッダー
- 「今日の案内」カード
- イベントの開催状態と開始時刻表示
- 「今日確認してほしいこと」の chip 一覧
- クイックアクセス
- 受付・スタッフへ誘導するヘルプ表示
- 色、余白、角丸、文字階層のデザイン意図

Home は次の dedicated subview へ分割する。

```text
HomeView
├── HomeHeader
├── TodayGuideSection
│   └── TodayGuideCard
├── CheckItemsSection
├── QuickAccessSection
│   └── QuickAccessCard
└── HelpBanner
```

各 subview へは表示値と action だけを渡し、Home 全体の state や service をそのまま渡さない。

### 5.2 Home のために残すロジック

Design Gate で固定表示を採用しない限り、次だけを Swift へ移植する。

- `/api/events/today` の取得
- API DTO から Home 用 event model への変換
- イベントの時刻順 sort
- `live` / `next` / `upcoming` / `ended` 判定
- 注目イベントの選択
- 開始までの案内文生成
- Home の確認項目データ

`openCampus.ts` は丸ごと移植せず、Home が使う部分だけを抽出する。時間割用 category、department filter、event detail 用補足は移植しない。

### 5.3 準備中画面への遷移

Design Gate で別案を採用しない限り、Home の action を次のように置き換える。

| 現行 action | 初回リリース |
|---|---|
| 「マップ」「場所を見る」「受付へ」 | Map タブの準備中画面 |
| 「イベント」「イベント詳細」 | 時間割タブの準備中画面 |
| 学校生活や案内情報への導線 | 情報タブの準備中画面 |

存在しない spot ID や event ID を準備中画面へ渡さず、将来仕様を固定しない。

### 5.4 データ取得失敗時

現行実装は API 失敗時に mock event を正常データとして表示する。SwiftUI 版は loading / latest / empty / failed を区別する。

通信失敗時に架空イベントを表示しない。Home の固定コンテンツは表示したまま、今日の案内部分だけに再読み込み導線または受付案内を表示する。

## 6. 再利用・移植・廃棄

### 6.1 Home のために移植する資産

| 現行資産 | 処置 |
|---|---|
| `app/index.tsx` | Home 起動時の取得意図だけ移植 |
| `HomeScreen.tsx` | 情報設計、文言、操作を Figma 経由で SwiftUI 化 |
| `AppCard.tsx` | Home 用 Figma component / SwiftUI View として再構築 |
| `SectionHeader.tsx` | Home 用 component として再構築 |
| `StatusPill.tsx` | Home の event status 表示として再構築 |
| `theme/tokens.ts` | Home と app shell に必要な token だけ移植 |
| `AppIcon.tsx` | SF Symbols または asset へ置換 |
| `src/api/events.ts` | Home が使う endpoint と mapper だけ Swift 化 |
| `src/types/events.ts` | Home に必要な最小 DTO / model だけ Swift 化 |
| `openCampus.ts` | Home が使う時刻判定、注目イベント、確認項目だけ移植 |
| event API / open-campus tests | Home に関係する assertion だけ Swift へ移植 |

`BottomNav.tsx` は3タブ前提なので移植せず、Figma と SwiftUI で4タブとして作り直す。

### 6.2 全て廃棄する非 Home 資産

#### Map

- `app/map.tsx`
- `src/components/MapScreen.tsx`
- `src/components/MapHeroCard.tsx`
- `src/components/CongestionBadge.tsx`
- `src/components/map/` 配下すべて
- `src/types/navigation.ts`
- `__tests__/map-search-overlay.test.tsx`
- spot / floor / route の RN client 利用
- 検索、floor switch、混雑 filter、route chip、bottom sheet
- 仮の現在地、仮 spot、名前部分一致の関連付け

#### 時間割・イベント一覧

- `app/events.tsx`
- `src/components/EventsScreen.tsx`
- category filter
- event detail sheet
- event から Map への route parameter
- 時間割画面の state、layout、style

`/api/events/today` と event status は Home が使う範囲だけ残す。時間割画面を復元できる形で Swift model を先回りして作らない。

#### 情報

- Web / RN / 文書内にある Info 画面候補の UI
- 学校生活、寮生活、学科、交通アクセスの既存画面構成
- Info 用の仮 navigation と content model

初回リリースで残すのは「情報は準備中です」という静的表示だけとする。

#### 地図・経路・センサー関連

- MapDataset client / cache
- MapKit / CoreLocation
- canonical map model の iOS 実装
- 経路探索、経路追従、屋内 floor map
- CoreMotion / CMAltimeter の本番統合
- Sensor Lab の API / repository / UI の本番転用

`apps/sensor-lab-ios` 自体は独立した検証アプリとして残せるが、本番アプリへコードを移さない。Sensor Lab の削除は別の明示判断で行う。

### 6.3 本番切り替え後に廃棄する基盤

- `apps/mobile-ios` 全体
- Expo Router / React Native / React Native SVG
- Metro / Babel / Jest / React Native Testing Library
- Expo app config と lockfile
- `@nexus/shared` の iOS からの参照
- Expo / Node を実行する `mobile-check`

管理 Web や API が利用している TypeScript package まで巻き込まず、削除前に参照元を確認する。

## 7. 目標プロジェクト構成

Home-only のため、将来機能の directory や domain layer を先に作らない。

```text
apps/nexus-ios/
├── NexusApp/
│   ├── App/
│   │   ├── NexusApp.swift
│   │   ├── AppView.swift
│   │   ├── AppTab.swift
│   │   └── ComingSoonView.swift
│   ├── Home/
│   │   ├── HomeView.swift
│   │   ├── HomeHeader.swift
│   │   ├── TodayGuideSection.swift
│   │   ├── CheckItemsSection.swift
│   │   ├── QuickAccessSection.swift
│   │   └── HelpBanner.swift
│   ├── Events/              # Home に必要な今日の案内だけ
│   ├── Networking/
│   ├── DesignSystem/
│   └── Resources/
├── NexusAppTests/
└── NexusAppUITests/
```

Map、Schedule、Info の feature directory は作らず、タブの case と `ComingSoonView` だけで表現する。

## 8. SwiftUI 実装ルール

- root の `AppView` が選択タブだけを所有する。
- Home の状態は Home 内に置き、準備中タブへ共有しない。
- Home service は initializer で注入する。
- 非同期取得は `.task` から小さな async method を呼ぶ。
- layout、API decode、時刻判定を同じ View に置かない。
- 大きな section は dedicated subview に分割する。
- 準備中画面は stateless にし、3画面で同じ View を使う。
- Figma component / variable と SwiftUI View / token の対応表を維持する。
- SF Symbols を優先し、RN の SVG path を移植しない。
- Dynamic Type、VoiceOver、44pt 以上の操作領域、Reduce Motion を完了条件に含める。

## 9. 段階的な実装計画

### Phase 0: Home-only 方針を正本化

- Home だけを初回提供する決定を Work item に記録する。
- Map / 時間割 / 情報を後続版へ移す。
- v1.0 または先行 MVP の完了条件を更新する。
- 最小 iOS、bundle ID、署名を確定する。

完了条件: Map / 経路 / Info / センサーが初回リリースの必須条件に残っていない。

### Phase 1: Figma 再設計と受入基準

- Figma の対象 file を決める。
- 現行 Home を基に通常・loading・empty・error を再構築する。
- 4タブと準備中3画面を作る。
- 本書 3.2 の未確定事項を対話で決める。
- component、semantic token、type style を作る。
- Figma frame と SwiftUI の受入 checklist を対応付ける。

完了条件: React Native の実装を読まずに SwiftUI Home の合否を判定でき、実装へ影響する未確定事項が残っていない。

### Phase 2: SwiftUI app shell を新設

- `apps/nexus-ios` と app/unit/UI test target を作る。
- Home / Map / 時間割 / 情報の4タブを作る。
- 非 Home 3タブへ共通 `ComingSoonView` を接続する。
- Figma で確定した token、asset、API environment の最小構成を作る。
- macOS runner の `ios-native-check` を追加する。

完了条件: 4タブを切り替えられ、準備中タブに API、mock、権限要求、隠れた機能がない。

### Phase 3: Home を SwiftUI へ移植

- Figma の各 section を dedicated SwiftUI View として実装する。
- 必要なら `/api/events/today` の最小 client、DTO、mapper を実装する。
- event status、注目 event、案内文を pure Swift で実装する。
- Home action を合意した準備中表示へ接続する。
- loading / loaded / empty / failed を実装する。
- Preview fixture を production fallback と分離する。
- Figma と Simulator screenshot を状態ごとに比較する。

完了条件: Home の全操作が行き止まりにならず、Figma との差分が受入 checklist の許容範囲内である。

### Phase 4: 非 Home 実装を削除

- RN の Map route、screen、components、types、mock、test を削除する。
- RN の Events route、screen、filter、detail sheet を削除する。
- Home が使わない `openCampus.ts` のデータと関数を削除する。
- 未接続 component の「将来利用予定」という判断記録を更新する。
- Map / route / Info / sensor を初回リリースへ接続する TODO を除去する。

完了条件: Swift repository に Map / 時間割 / Info の model や service がなく、削除対象が Git 履歴から復元可能である。

### Phase 5: リリース検証と切り替え

- Home の unit test、API contract test、最小 XCUITest を実行する。
- 初回 install、更新 install、offline、5xx、不正 JSON を確認する。
- 実機で Safe Area、文字サイズ、VoiceOver、light/dark 方針を確認する。
- bundle ID と署名を確認し、TestFlight build を作成する。
- App Store の説明とスクリーンショットを Home-only に合わせる。

完了条件: Home と準備中3画面だけで release candidate が成立し、未使用権限を要求しない。

### Phase 6: Expo / React Native を完全撤去

- 本番切り替え後に `apps/mobile-ios` を削除する。
- Expo / RN の依存、config、CI job、README 手順を削除する。
- API 変更チェック対象を `apps/nexus-ios` へ切り替える。
- Home の仕様、Figma link、判断記録だけを docs に残す。

完了条件: iOS の build、test、archive が Node / Expo / React Native に依存せず、旧 Map / 時間割 / Info 実装が残っていない。

## 10. テスト移行マップ

| 現行テスト | 処置 |
|---|---|
| `events-api.test.ts` | Home が使う success / empty / HTTP error / decode error を Swift へ移植 |
| `open-campus.test.ts` | Home が使う event status / featured event だけ Swift へ移植 |
| `map-search-overlay.test.tsx` | 移植せず削除 |
| Events screen | 準備中表示だけ UI test |
| Map / route / sensor | 初回リリースではテスト対象を作らない |

最小 UI test は次の3本とする。

1. 起動すると Home が表示される。
2. Home の Map action から Map の準備中表示へ移動できる。
3. 各タブが対応する準備中タイトルを表示する。

## 11. 初回リリースの受入条件

- Figma で承認された Home が SwiftUI で実装されている。
- Home の主要 section、文言、視覚階層が checklist と一致する。
- 今日の案内は loading / latest / empty / failed を区別する。
- Map / 時間割 / 情報は一貫した「準備中」表示である。
- Home の action は無反応にならない。
- Map、検索、経路、位置情報、センサー、時間割一覧、Info content は実装されていない。
- App binary に React Native runtime、Expo、JavaScript bundle を含まない。
- 未使用権限を要求しない。
- Home の unit/UI test と Xcode build が CI で成功する。
- TestFlight で実機表示を確認済みである。

## 12. 直近の実行順

1. Home-only の製品スコープを正本へ反映する。
2. Figma の既存 file を使うか、新しい file を作るか決める。
3. 現行 Home から low-fidelity の4状態を作る。
4. 本書 3.2 の未確定事項を対話で決める。
5. Figma の Home、4タブ、準備中3画面、component、token を完成させる。
6. `apps/nexus-ios` と4タブの app shell を作る。
7. Home を section 単位で SwiftUI へ移植する。
8. Home に必要な event API と pure logic だけを移植する。
9. 自動テストと実機確認を完了する。
10. RN の Map / 時間割 / Info 関連実装を削除する。
11. TestFlight 切り替え後に Expo 基盤を削除する。

## 13. 調査時点の基準

以下は **2026-09-07 の計画立案時点**の観測値である。現在の状態は §13.1 を参照する。

- 現行 Home: `apps/mobile-ios/src/components/HomeScreen.tsx`
- 現行 Home route: `apps/mobile-ios/app/index.tsx`
- Home が利用する API: `GET /api/events/today`
- 現行 RN TypeScript: 型チェック成功
- 現行 Jest: ローカル依存欠損で起動不能。clean install 時の記録は3スイート17テスト成功
- Sensor Lab: generic iOS device build 成功。ただし本計画では本番へ移植しない
- 本番用 SwiftUI target: 現在なし
- Figma target file: 未決定

既存の Map、時間割、情報、経路、センサー関連コードが存在することは、初回リリースへ含める根拠にしない。

### 13.1 現在の状態（2026-09-22 時点の静的確認）

計画立案時から変化しているため、上記の基準をそのまま使わない。

- **本番用 SwiftUI target: 存在する。** `apps/nexus-ios/Nexus.xcodeproj`（2026-09-19 作成）。Swift 80 ファイル、テスト 10 本。
- タブ構成は `Nexus/Application/AppTab.swift` に `home` / `map` / `guide` / `search` として実装済み。
- **データ取得・地図・経路は未接続。** `import MapKit` / `import CoreLocation` / `URLSession` / `UserDefaults` / `FileManager` / `CoreData` / `SwiftData` の出現はいずれも 0 件。各 `*Client` の本番既定は `.unconfigured`、地図描画面は `MapSurfaceProvider.unavailable`。
- **`apps/nexus-ios` は `Nexus.sln`・`.gitlab-ci.yml`・`.github/workflows/ci.yml` のいずれにも未登録。** 自動検証を一度も通っていない。

実装が存在することと、実装が完了していることを分けて扱う。
