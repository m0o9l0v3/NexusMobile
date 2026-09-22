# E0-6: 参加者向け iOS クライアントの正本を確定する

- 移行元ID: E0-6 / 区分: E0 / 根拠: [Work item #82](https://gitlab.com/11h27m/nexus-mobile/-/work_items/82) 以下の発行記録（2026-09-07）、`apps/nexus-ios` の実装、2026-09-22 のリポジトリオーナーの判断
- 判断日: 2026-09-22
- 判断者: リポジトリオーナー（技術的意思決定者）
- 状態: 採用

## 採用方針

**参加者向け iOS クライアントの正本を `apps/nexus-ios`（SwiftUI）とする。**

- `apps/nexus-ios` の現在の実装内容を正しいものとして扱う。
- `apps/mobile-ios`（Expo SDK 54 / React Native 0.81 / expo-router v6）は**撤去対象**とし、正式な提供物としない。
- [`docs/ios-native-migration-plan.md`](../ios-native-migration-plan.md) は「未承認の草案」ではなく、**承認済み・実装進行中の計画**として扱う。ただし同文書の「Home のみ移植し、他タブは準備中表示」という初回リリース境界は現状と一致しないため、同文書の冒頭注記を正とする。

## 判断の背景

E0-6 判断以前、iOS クライアントの正本は次の3つの記述に分かれていた。

| 出典 | 記述 | 更新日 |
|---|---|---|
| `docs/v1.0-scope.md` | 「参加者向けアプリ機能を正式提供するクライアントは iOS アプリだけ」。**どちらのアプリか明記なし** | 2026-08-31 |
| `docs/implementation/parallel-issue-selection.md` | アーキテクチャ節で `apps/mobile-ios` を記載。**`apps/nexus-ios` への言及なし** | 2026-09-05 |
| `docs/ios-native-migration-plan.md` | **未承認の草案**と明記。SwiftUI へ移行し Expo/RN を完全撤去 | 2026-09-11 |

一方、Work item は 2026-09-07 の時点で SwiftUI 移行を正式に発行済みだった。

| Work item | タイトル |
|---|---|
| [#82](https://gitlab.com/11h27m/nexus-mobile/-/work_items/82) | Nexus iOS v1.0 — 構内案内マップアプリのSwiftUI移行（親） |
| [#46](https://gitlab.com/11h27m/nexus-mobile/-/work_items/46) | SwiftUIアプリ基盤と4タブ構成の実装 |
| [#47](https://gitlab.com/11h27m/nexus-mobile/-/work_items/47) | Home画面のSwiftUI移行 |
| [#85](https://gitlab.com/11h27m/nexus-mobile/-/work_items/85) | Map画面と地点詳細の実装 |
| [#86](https://gitlab.com/11h27m/nexus-mobile/-/work_items/86) | 案内画面と案内詳細の実装 |
| [#27](https://gitlab.com/11h27m/nexus-mobile/-/work_items/27) | 探す画面とMap連携の実装 |
| [#87](https://gitlab.com/11h27m/nexus-mobile/-/work_items/87) | 統合試験・アクセシビリティ・TestFlight・旧実装整理 |

**決定は行われ Work item にも記録されていたが、`docs/v1.0-scope.md` へ反映されていなかった。** 本記録はその反映である。

## 現在の実装状態（2026-09-22 時点の静的確認）

`apps/nexus-ios` は Swift 80 ファイル、テスト 10 本。実装が完了しているのは**4タブの UI フロントエンドと注入境界**であり、データ取得・地図・経路は未実装である。

| 確認項目 | 結果 |
|---|---|
| `import MapKit` / `import CoreLocation` | **0 件** |
| `URLSession` / `URLRequest` | **0 件** |
| `UserDefaults` / `FileManager` / `CoreData` / `SwiftData` | **0 件** |
| 地図描画面の本番既定 | `MapSurfaceProvider.unavailable` → 「構内地図は未提供です」（`Nexus/Features/Map/Data/MapSurfaceProviding.swift:39-41`） |
| データ取得の本番既定 | `HomeClient` / `MapContentClient` / `SearchClient` / `GuidanceClient` はすべて `.unconfigured` で throw または未提供を返す |
| 経路確認の本番既定 | `RouteRequestHandling.unconfigured` → 「経路案内は未提供です」 |

したがって **E3（屋外地図・位置情報）・E4（経路探索）・E5（屋内）はほとんど未実装**であり、E6（タブ構成・Home）の UI 部分が先行している。`MapSurfaceProviding.swift:5-7` のコメントも「実際の描画方式の採用は #85・#24 の判断であり、ここでは決めない」と明記しており、注入境界を意図的に空けた設計である。

**既存コードが存在することを、実装完了の根拠にしない。**

## 正しく実装されている契約

移行にあたり、次は `apps/nexus-ios` 側で既に E1-3 に沿って実装されている。

- `CanonicalSpotID`（`Nexus/Features/Home/Models/HomeModels.swift:3-11`）は rawValue をそのまま保持し、大文字小文字を区別する。表示名から導出しないことをコメントで明示している。
- `RouteRequestOutcome.unknownSpot`（`Nexus/Features/Route/Data/RouteRequestHandling.swift:18`）は、未知の canonical ID を**別地点へ置換しない**。

## 理由

- Work item #82〜#87 として既に正式発行され、実装も `apps/nexus-ios` に集約されている。実態と記録の両方が SwiftUI を指している。
- 4タブ構成（E6-1）の実装が `apps/nexus-ios` にのみ存在する。
- `apps/mobile-ios` には Phase 1 モック ID（`entrance` / `room-a` / `1F`）が残っており、E1-2 が移行対象と定めている。正本として維持する利点がない。

## 却下した選択肢

- **`apps/mobile-ios` を正本として維持する**: SwiftUI 移行が Work item として発行済みであり、4タブ実装も `nexus-ios` にしかない。二重実装の維持コストに見合わないため却下。
- **両方を正式提供物として併存させる**: 機能同期の負担が発生し、`docs/v1.0-scope.md` が禁じる「iOS と機能同期」に近い状態を内部に作るため却下。
- **`docs/ios-native-migration-plan.md` を未承認のまま据え置く**: 実装が先行して進んでおり、文書だけが未承認である状態は判断の追跡を妨げるため却下。

## 後続Issueが前提にできる事項

- 参加者向け iOS の実装先は `apps/nexus-ios` である。
- E3〜E5 の実装は、`nexus-ios` に用意済みの注入境界（`MapSurfaceProviding`、各 `*Client`、`RouteRequestHandling`）へ接続する形で行う。**作り直しではない。**
- `apps/mobile-ios` への機能追加は行わない。撤去時期は [#87](https://gitlab.com/11h27m/nexus-mobile/-/work_items/87) の範囲で判断する。

## 本Issueのスコープ外

- `apps/mobile-ios` の具体的な撤去手順と時期
- E3〜E5 の実装方式（地図描画エンジン、経路探索アルゴリズム）
- `apps/nexus-ios` のビルド・CI 統合（別途対応が必要。§既知の課題）
- Android / Kotlin Multiplatform の採否

## 既知の課題

**`apps/nexus-ios` は `Nexus.sln`・`.gitlab-ci.yml`・`.github/workflows/ci.yml` のいずれにも登録されていない。** Swift 80 ファイルとテスト 10 本が自動検証を一度も通っていない状態である。正本と定めた以上、ビルド・テストの検証経路を用意する必要がある。macOS runner の確保を含めて別途対応する。
