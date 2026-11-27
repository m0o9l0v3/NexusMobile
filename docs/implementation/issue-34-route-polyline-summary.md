# Issue #34　経路ポリラインと徒歩の目安

## 地図に表示するまで

Map と経路探索は同じ `PinnedBundleSource` を読む。構成は `RoutingEngine` → `BundleRouteSolver` → `RouteRequestStore` → `MapSurfaceContext` → `MapKitMapSurfaceView`。下部の `RouteSummaryCardView` は同じ `ResolvedRoute` をストアから受け取る。

- ポリラインには各ステップの進行方向の座標を使う。正式入口の閾値は屋外・屋内の両区間に含める。階層間の抽象遷移では区間を切る。始終点マーカーは探索が選んだノードの位置に置く。
- 距離と徒歩の目安は `RoutePath.totalDistanceMeters` と `totalEstimatedSeconds` を丸めて表示する。[正本サンプル](../schemas/examples/participant-bundle-v2.example.json)の航空神社から電気装備教室までは4ステップ・2区間で、配信値の合計は57.7 m・53秒、表示は「58 m」「徒歩 1分未満（目安）」。
- 新しい経路の確定と「全体を表示」「経路へ戻る」でカメラを合わせる。地点の閲覧中は上部のバナーに案内先を残す。案内中に詳細を閉じたときとマップタブに戻ったときは、案内を開始した地図の版を保持する。
- AX1〜AX5では距離・時間と操作ボタンを縦に並べる。要約と検索欄の高さを地図に反映し、要約が長いときはカード内をスクロールできる。案内中の地図では始終点のラベルを優先し、ほかの地点ピンもタップ・読み上げで選べる。

## 要求の結果

| 条件 | 表示・動作 |
| --- | --- |
| 出発地と目的地の到達ノードが同じ | 同じ地点であることを通知する。新しい経路線は作らない。 |
| 2点が別の連結成分にある | 未接続であることと、直線案内を行わないことを示す。 |
| 同じ連結成分内で片方向制約・通行条件により到達できない | 通行できる経路がないことと、直線案内を行わないことを示す。 |
| 目的地または出発地が経路対象外 | どちらの地点かを示し、接続地点の未設定・不正・代表入口の重複を説明する。 |
| 未知の目的地・出発地 | 指定されたIDと、その地点が未登録であることを示す。 |
| 出発地が未設定 | 出発地が必要であることを通知する。 |
| 地図なし・有効辺なし | 歩行経路が未公開であることを通知する。 |
| 公開データを読めない／接続先が未設定 | 取得失敗・保存版なしはデータ未提供、接続先が未設定なら従来の「経路案内は未提供です」を表示する。 |

同一点を含め、受理されなかった要求では現在の案内先と経路を保持する。「案内を終了」は案内先・経路・通知をクリアする。

## 関連 Issue と Figma 確認事項

| Issue | 引き継ぎ |
| --- | --- |
| #35 | 簡易ステップ案内は `ResolvedRoute.path.steps` と `traversedFloorIDs` を利用できる。 |
| #85 | 本番の出発地選択と地点詳細からの統合を担当する。出発地の注入には `requestRoute(from:to:from:)` を使う。通常起動は出発地未設定。 |
| #32 | 実測した歩行ネットワークを提供する。今回の画面確認にはDEBUG専用の合成データを使った。 |
| #38 | 屋内SVGの描画を担当する。今回の屋内区間はMapKit上に描く。 |

Figmaとの照合では以下を確認する。[既存の引き継ぎ H-6・L-5](../design/figma-handoff-2026-11.md)はオーナー判断待ち。経路要求後は要求元のタブに留まる。

- 屋外は縁9 pt・芯5 ptの実線、屋内は縁7 pt・芯4 ptの破線（8 pt・6 pt）。芯はアクセント色、縁は `OnAccent`。
- 「出発」は歩行者アイコンと枠、「目的地」は `CautionAccent` 上の旗で表示する。通常文字サイズでは地点詳細のピンと近接する場所のラベルも確認する。
- 下部カードの目的地名、徒歩の目安、距離、屋内の建物・階名、「全体を表示」「案内を終了」の順序と配置。
- 詳細閲覧中の「経路へ戻る」バナー、同一点・到達不能・未接続・対象外の通知文と配置。

## DEBUG での画面確認

Xcode の Nexus スキームの Run → Arguments Passed On Launch に、表の起動引数を設定する。各引数はスペースで区切った2項目として渡す。シナリオを省略した場合は `found`。データには「検証用の仮経路データ（実測データではありません）」を表示する。

| 起動引数 | 確認内容 |
| --- | --- |
| `-NexusRouteCheck found` | 正門付近から格納庫Aへの曲がりのある屋外線、228 m・約3分 |
| `-NexusRouteCheck indoor` | 電気装備教室へ、教室棟の正式入口で実線から破線へ切り替わる |
| `-NexusRouteCheck samePoint` | 正門付近と同一点 |
| `-NexusRouteCheck disconnected` | 技能審査棟は別の連結成分 |
| `-NexusRouteCheck unreachable` | 格納庫Bへの逆向き一方通行 |
| `-NexusRouteCheck notRoutable` | 実習棟の接続地点が未設定 |
| `-NexusRouteCheck unknown` | 指定IDが未登録 |
| `-NexusRouteCheck unavailable` | 経路探索に使う公開データが未提供 |

シミュレーターで屋内経路の要約、別地点の詳細から元の経路へ戻る操作、案内終了を確認した。AX3の屋外経路で始終点と縦積みの要約を確認した。読み上げ名はアクセシビリティツリーで確認した。VoiceOverの実機音声と現地での歩行は未検証。

## テスト結果

2026-11-23 JST、macOS 27.0.1、Xcode 27.2（27B52）、iOS Simulator SDK 27.2、iPhone 17（arm64、iOS 26.5 / 23F77）で実行した。

```sh
xcodebuild \
  -project apps/nexus-ios/Nexus.xcodeproj \
  -scheme Nexus \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination "platform=iOS Simulator,id=B044E8BC-A71E-4159-9587-3034908E910D" \
  -derivedDataPath /tmp/nexus-ios-derived-data \
  ONLY_ACTIVE_ARCH=YES CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO \
  -parallel-testing-enabled NO \
  test
```

| 検証 | 成功件数 |
| --- | ---: |
| 既存スイート | 565 |
| RoutePresentationTests | 10 |
| BundleRouteSolverTests（DEBUGの8シナリオを含む） | 12 |
| AccessibilityContrastTests の経路色・要約文字の追加試験 | 1 |
| **合計** | **588** |

`xcodebuild` は終了コード0、`TEST SUCCEEDED`。結果バンドル `Test-Nexus-2026.11.23_21-19-00-+0900.xcresult` の集計は成功588・失敗0・スキップ0。徒歩時間の既存の境界値テストでは、3569秒を「約59分」、3570秒と3599秒を「約1時間」と表示することも確認した。DEBUGの合成データは公開bundle 2.1.0とGeoJSON 2.0.0のJSON Schemaにも適合した。

## 変更ファイル

- [AppShellModel.swift](../../apps/nexus-ios/Nexus/Application/AppShellModel.swift)
- [NexusApp.swift](../../apps/nexus-ios/Nexus/Application/NexusApp.swift)
- [NexusAppShell.swift](../../apps/nexus-ios/Nexus/Application/NexusAppShell.swift)
- [MapModels.swift](../../apps/nexus-ios/Nexus/Features/Map/Models/MapModels.swift)
- [MapStore.swift](../../apps/nexus-ios/Nexus/Features/Map/State/MapStore.swift)
- [MapKitMapSurfaceView.swift](../../apps/nexus-ios/Nexus/Features/Map/Views/MapKitMapSurfaceView.swift)
- [MapRootView.swift](../../apps/nexus-ios/Nexus/Features/Map/Views/MapRootView.swift)
- [RouteRequestHandling+Bundle.swift](../../apps/nexus-ios/Nexus/Features/Route/Data/RouteRequestHandling+Bundle.swift)
- [RouteRequestHandling.swift](../../apps/nexus-ios/Nexus/Features/Route/Data/RouteRequestHandling.swift)
- [RouteCheckFixtures.swift](../../apps/nexus-ios/Nexus/Features/Route/Fixtures/RouteCheckFixtures.swift)
- [RoutePresentationModels.swift](../../apps/nexus-ios/Nexus/Features/Route/Models/RoutePresentationModels.swift)
- [RouteRequestStore.swift](../../apps/nexus-ios/Nexus/Features/Route/State/RouteRequestStore.swift)
- [RouteRequestNoticeView.swift](../../apps/nexus-ios/Nexus/Features/Route/Views/RouteRequestNoticeView.swift)
- [RouteSummaryCardView.swift](../../apps/nexus-ios/Nexus/Features/Route/Views/RouteSummaryCardView.swift)
- [AccessibilityContrastTests.swift](../../apps/nexus-ios/NexusTests/AccessibilityContrastTests.swift)
- [BundleRouteSolverTests.swift](../../apps/nexus-ios/NexusTests/Route/BundleRouteSolverTests.swift)
- [RoutePresentationTests.swift](../../apps/nexus-ios/NexusTests/Route/RoutePresentationTests.swift)
- 本実装記録
