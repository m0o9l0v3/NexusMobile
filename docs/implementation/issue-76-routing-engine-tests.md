# Issue #76: 端末内経路探索エンジンのユニットテスト

対象は [E4-2 の探索と目的地解決](../decisions/E4-2-routing-engine.md)。NexusTests の次の4ファイルで検証する。

| ファイル | 役割 |
| --- | --- |
| [RoutingTestFixtures.swift](../../apps/nexus-ios/NexusTests/Route/RoutingTestFixtures.swift) | 合成ノード、辺、正式入口と、通常経路・同一点の検査 |
| [RoutingEngineTests.swift](../../apps/nexus-ios/NexusTests/Route/RoutingEngineTests.swift) | 指標・方向・通行属性・階の異なる既知グラフで経路を比較（11件） |
| [DestinationNodeResolverTests.swift](../../apps/nexus-ios/NexusTests/Route/DestinationNodeResolverTests.swift) | 目的地4種別の到達ノードと失敗理由を検査（6件） |
| [RoutingGeoJSONDecodingTests.swift](../../apps/nexus-ios/NexusTests/Route/RoutingGeoJSONDecodingTests.swift) | 公開サンプルのデコードから探索まで、不正辺の除外と診断を検査（4件） |

## 方針

合成グラフで距離、時間、方向、入口と階の所属を明示し、手で決めた期待経路と照合する。ID・座標・移動コストは試験値であり、現地の測量値や承認された遷移仕様には使えない。配信との接続は、既存の bundle 検証と同じ[正本サンプル](../schemas/examples/participant-bundle-v2.example.json)を直接読み込む。小数の合計のアサーションには `accuracy: 1e-9` を使う。探索自体は厳密比較を使う。

## 期待結果と失敗判定基準

| 観点 | 期待結果 | 失敗として扱う例 |
| --- | --- | --- |
| 最短距離・最短時間 | 距離優先は2辺で 2.3 m / 8.4 s、時間優先は直行の 9 m / 1.5 s | ホップ数だけで直行を選ぶ、副指標を誤って合計する |
| 同点 | 主指標、副指標、辺数が等しければ辺 ID 列全体の辞書順で選ぶ。入力順を逆転・入れ替えしても同じ | ノード順・最後の辺の ID・入力順で別経路になる |
| 座標と方向 | 正方向は元の3点、逆方向は中間点を含む逆順。ステップの両端も進行方向に一致 | 逆走時に座標や端点が正方向のまま |
| ID と同一点 | 大文字小文字の違う既知 ID は別ノード。未知 ID 同士は失敗。同じ既知ノードは孤立していても 0 m・0 s・空ステップ。同じ到達点を持つ2部屋も同じ結果 | 誤った ID に置換、未知ノードで成功、同一点で通常経路を返す |
| 未接続と片方向 | 孤立・別成分は `disconnected`。片方向辺の順方向は成功し、逆方向は `unreachable`。合法な迂回路があればそちらを通る | 逆走する、2種類の失敗を混同する、迂回路を見落とす |
| 通行属性 | 通常は3値とも通行可。`accessibleOnly` は `not_accessible` と `unknown` の双方を迂回し、他に通れる辺がなければ `unreachable` | 未確認を通行可とする、距離を優先して制約を破る |
| 正式入口・同一階 | 正式入口を両方向とも 0 m / 0 s で通る。別ノードのため通常経路。並列入口を往復せず廊下へ進み、通行方針に応じて入口を切り替える。同一階内の廊下はフロア1個 | 二重加算、0コストの往復、利用不可の入口を選ぶ |
| 階層跨ぎ（抽象辺） | 屋外→入口→廊下→1F→2F→3F。階段と EV を方針で選び分け、未確認 EV は除く。一方通行の逆向きは `unreachable`、孤立した4Fは `disconnected` | 階を取り落とす、屋外・連続する同じ階を列に含める、逆向きの遷移を許す |
| 部屋・ランドマーク・建物 | 明示した `destination` ノードが種別・建物・階の規則に合う場合だけ解決する。欠落は `missingAccessNode`、不正な明示参照は `invalidAccessNode` | 違う建物・階・ノード種別を許す、不正な明示参照を代表入口で代替する |
| 建物の代表入口・正式入口の側 | 建物は明示指定が無いときだけ代表入口の外側へ。代表0件は欠落、2件は曖昧。正式入口は出発点が屋外・別建物なら外側、同一建物なら内側 | 非代表入口を選ぶ、候補の先頭で曖昧さを隠す、別建物から内側へ解決する |
| 目的地間の探索 | ノード・歩行辺・未知・大文字小文字違いの目的地 ID は `unknownDestination`。入口を出発地にした場合の側も指定できる | 別目的地に置換、到達ノード自体を目的地として受理 |
| 配信サンプル | `campus_lm_001` → `mb_1f_cl_001` は屋外辺2本、正式入口、屋内辺の順で **57.7 m / 53 s**。屋外辺1本が未確認なので `accessibleOnly` は `unreachable` | 座標から重みを再計算する、入口の位置や属性を失う |
| グラフ構築 | 重複 ID・自己ループ・片端の欠落・未知端点・非正／非有限の重み・別階への屋内歩行辺は対象 ID と理由を診断する。正常辺だけで所定の方向・配信重みの経路となる。未知 Feature 種別は無視する | 不正辺を通れる、重複の一方を採用、正常辺まで失う、未知種別を遷移に変換する |

## 実行

リポジトリのルートから、次のコマンドで既存スイートも含めて実行する。

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

### 実行結果

2026-11-23 19:51:23〜19:51:28 JST に実行。Xcode 27.2（27B52）、iOS Simulator SDK 27.2、iPhone 17（arm64、iOS 26.5 / 23F77、UDID `B044E8BC-A71E-4159-9587-3034908E910D`）を使用した。

| スイート | 実行数 | 成功 | 失敗 |
| --- | ---: | ---: | ---: |
| RoutingEngineTests | 11 | 11 | 0 |
| DestinationNodeResolverTests | 6 | 6 | 0 |
| RoutingGeoJSONDecodingTests | 4 | 4 | 0 |
| 既存の NexusTests | 544 | 544 | 0 |
| **全件** | **565** | **565** | **0** |

XCTest は全件の所要時間を 0.871 秒と報告した。`xcodebuild` は終了コード 0、`** TEST SUCCEEDED **`。結果バンドル `Test-Nexus-2026.11.23_19-51-24-+0900.xcresult` の集計でも 565 件成功、失敗・スキップともに 0 件だった。

## #87 への引き継ぎと範囲外

- #87 では上の全件実行を再現し、#34・#35・#85 の接続後、選んだ目的地 ID・進行方向・フロア・距離と時間・探索失敗理由が画面まで対応することを確かめる。本番の注入先は現在 `.unconfigured`。
- #79 は実測した構内データで主要6経路とその到達ノードを確認する。今回の合成値・正本サンプルは現地経路の受け入れ判定には使えない。
- #80 の GPS 精度と電池消費の計測は実機で行う。本記録の時間はユニットテストの実行時間。
- #42 の階段・EV・建物間連絡の配信形式は未確定。改訂2確定後に GeoJSON 取り込みから階層跨ぎまでの検査を追加する。今回の階層跨ぎは直接構築したグラフを対象とする。
