# OS非依存・グラフ吸着型の屋内現在地推定構想案（草案）

> **状態: 構想案（草案）**
> 本書は将来の屋内現在地特定・経路追従に向けた技術構想メモであり、[`docs/v1.0-scope.md`](v1.0-scope.md) の必須成果やリリース条件を拡張するものではありません。v1.0 の製品境界を変更する場合は、`docs/v1.0-scope.md` のスコープ変更ルールに従い GitHub Issue で判断を記録してください。

- 起案日: 2026-10-24
- 前提の背景:
  - 旧 `apps/sensor-lab-ios/`（気圧センサー `CMAltimeter` 単体による階層移動検証アプリ）は、本番接続の見通しおよび単体検証アプリとしての将来性がないため凍結・撤去済み（コミット `482bed5`）。
  - 卒業研究の残り期間（約2年）で実装・実証・評価まで完結でき、かつ将来 Android 版へ展開した際に **「iOS 固有の API や上位機種専用のセンサー（気圧計・UWB・LiDAR 等）を前提としない」** 方式を採用する。
- 関連文書・契約:
  - [`docs/v1.0-scope.md`](v1.0-scope.md)（v1.0 製品境界）
  - [`docs/decisions/E1-4-r1-destination-features.md`](decisions/E1-4-r1-destination-features.md)（GeoJSON payload 契約 2.0.0）
  - [`docs/decisions/E2-5-participant-data-delivery-v2.md`](decisions/E2-5-participant-data-delivery-v2.md)（参加者向け公開データ配信契約 v2）
  - [`docs/phase1/route-ui-event-contract.md`](phase1/route-ui-event-contract.md)（ルート表示 UI イベント契約）

---

## 1. 解決したい課題と設計制約

GPS が届かない校舎内（`mb` / `ptb` 等）において、オープンキャンパス参加者が現在地を見失わずに目的地へたどり着けるようにする。ただし、次の制約をすべて満たす必要がある。

1. **OS・端末非依存（iOS / Android 共通）**
   - 廉価〜中価格帯の Android 端末では非搭載が多い気圧センサー（`CMAltimeter` / `TYPE_PRESSURE`）や、iOS 固有の ARKit / RoomPlan / UWB を必須要件にしない。
   - すべてのスマートフォンに 100% 搭載されている **「歩数・歩行距離検知」「角速度（相対的な回転角）」「カメラ（QR 読み取り）」「画面タップ」** のみで成立させる。
2. **追加ハードウェア設置ゼロ**
   - 校舎内への BLE ビーコン大量設置や電源・死活監視を前提としない。
3. **不確実な位置を捏造しない**
   - 2次元平面上の自由な座標推定（Blue Dot の連続描画）は、センサー誤差の蓄積により壁抜けや誤案内を招くため行わない。
   - Nexus が配信する `map.geojson` の屋内トポロジーグラフ（`indoor_node` / `walking_path`）上の **1次元進行とチェックポイント通過** に制約する。
4. **独立検証アプリを作らず、純粋ロジック＋リプレイ試験で検証する**
   - 旧 Sensor Lab のように本番から切り離された別アプリを作らず、`apps/nexus-ios/NexusTests/` で JSON/CSV フィクスチャを用いた決定論的な単体テストとして検証し、将来 Kotlin（Android）へ 1 対 1 で移植できる構造にする。

---

## 2. 組み合わせる3つの技術要素

### 要素①：歩行ステップ検知 ＋ 廊下グラフ吸着（1次元 PDR マップマッチング）

自由な 2D 座標 `(lat, lon)` を推測するのではなく、**「現在乗っている廊下エッジ（`walking_path`）の上を、歩いた距離分だけ進む」** という 1 次元移動に制約する。

- **利用するセンサー（OS 標準・全端末搭載）**
  - iOS: `CMPedometer`（歩数・推定距離）
  - Android（将来）: `Sensor.TYPE_STEP_DETECTOR` / `TYPE_STEP_COUNTER`（歩数 × 推定歩幅）
- **グラフ吸着の仕組み**
  - 出発ノード（例：正式入口 `mb_ent_001` の `inside_node_id`）から案内中の経路エッジ `walking_path` に沿って、検知された歩行距離 $d$ メートル分だけ進行率 $t \in [0, 1]$ を進める。
  - 廊下の外（教室の壁の中など）には構造上絶対に外れないため、直進中の横ズレ誤差がゼロになる。

### 要素②：相対回転角による「曲がり角（交差点）」通過判定

屋内の鉄骨構造で狂いやすい地磁気コンパス（絶対方位・北の向き）は使わず、ジャイロセンサーによる **短時間の相対的な向き変化（例：「直進状態から左へ約 90 度曲がった」）** だけを検出する。

- **利用するセンサー（OS 標準・全端末搭載）**
  - iOS: `CMDeviceMotion`（`attitude.yaw` の短時間差分）
  - Android（将来）: `Sensor.TYPE_GAME_ROTATION_VECTOR`（地磁気を使わない相対回転ベクトル）
- **交差点（`junction`）との照合**
  - 要素①の歩行距離により次の分岐ノード（`node_kind: junction`）の前後許容範囲（例：$\pm 5\text{m}$）に近づいた状態で、経路グラフ上の折れ曲がり角度（左折・右折）と一致する相対回転角（例：$\pm 60^\circ \sim 120^\circ$）を検知したとき、**「その交差点を曲がって次の廊下エッジへ入った」** と確定させ、距離の累積誤差を交差点座標でリセットする。

### 要素③：確実なアンカー固定（入口遷移・QR・手動チェックポイント）

センサーのみでは初期位置の特定や長距離移動後の誤差解消ができないため、誤差を $0\text{m}$ にリセットする「確定アンカー」を3経路用意する。

1. **屋外 GPS から正式入口（`formal_entrance`）への自動ハンドオフ**
   - 屋外で `CoreLocation` の現在地が目的地建物の `formal_entrance`（`outside_node_id`）の一定半径内に入り、直後に歩行が継続して屋内に入った場合、接続先の `inside_node_id`（1F エントランス）を初期アンカーとして自動セットする。
2. **現地 QR コード読み取りによるピンポイント確定**
   - 階段踊り場、エレベーター前、主要な分岐点や教室入口に設置された案内 QR（`?code=XXXX`）を読み取った際、`ExternalSpotIDResolver`（[#109](https://github.com/m0o9l0v3/NexusMobile/issues/109)）を通じて該当 Spot の `placement.access_node_id` と `floor_id` に現在地を即座に確定させる。
3. **ステップ UI 上の「ここを通過／いまこの階にいる」ワンタップ補正**
   - 階段・EV ノード（`node_kind: transition`）に到達した際、自動で階を決めつけず、画面上のステップカードで「2F に上がりましたか？ [2F へ切替]」とワンタップで確定できるようにする（[`docs/phase1/route-ui-event-contract.md`](phase1/route-ui-event-contract.md) の `onApproachFloorTransition` / `onFloorTransitionCompleted` に対応）。

---

## 3. アーキテクチャ：OS 非依存の抽象イベント契約

将来 Android（Kotlin）へ同じロジックをそのまま移植できるよう、センサーのハードウェア制御層と、屋内グラフ上の位置推定ステートマシンを完全に分離する。

```text
[OS センサー / UI 層]                      [純粋ドメイン層（Swift / 将来 Kotlin 共通設計）]
・CoreLocation / CMPedometer               IndoorGraphTracker（状態マシン）
・CMDeviceMotion (相対 Yaw 差分)   ───►    ・入力: IndoorPositionEvent + MapGeoJSON (2.0.0)
・QR 読取 / ステップ手動タップ              ・出力: IndoorTrackingState
```

### 3.1 エンジンへの入力イベント（4種類のみ）

```swift
/// OS やハードウェアに依存しない屋内測位エンジンへの入力イベント
enum IndoorPositionEvent: Equatable, Sendable {
    /// ① 確実な現在地ノードが確定した（正式入口通過・QR読取・手動選択）
    case anchorConfirmed(nodeID: String, floorID: String, source: AnchorSource)

    /// ② 歩行による前進が検知された（歩数計からの増分距離 [m]）
    case stepAdvanced(distanceMeters: Double)

    /// ③ 短時間の方向転換が検知された（右折: 正、左折: 負の相対角度 [deg]）
    case turnDetected(deltaHeadingDegrees: Double)

    /// ④ 階層遷移の完了が通知された（手動タップ確認、または補助センサーによる確定）
    case floorTransitionConfirmed(targetNodeID: String, targetFloorID: String)
}

enum AnchorSource: String, Equatable, Sendable {
    case entranceGPS      // 屋外GPSから正式入口への進入
    case qrCode           // 現地QRコードの読み取り
    case manualSelection  // ユーザーによる「ここを出発地/現在地にする」操作
}
```

### 3.2 エンジンの出力状態

```swift
/// MapStore や経路案内 UI が購読する屋内推定状態
struct IndoorTrackingState: Equatable, Sendable {
    /// 現在位置が特定できているフロア（未確定時は nil）
    let currentFloorID: String?
    /// 現在乗っている経路上のノードまたはエッジ
    let position: GraphPosition?
    /// 次のフロア遷移（階段・EV）に接近している場合のサジェスト情報
    let pendingFloorTransition: FloorTransitionPrompt?
    /// 推定の信頼度（低下時は QR 読取または手動ステップ選択を促す）
    let confidence: TrackingConfidence
}

enum GraphPosition: Equatable, Sendable {
    case atNode(nodeID: String)
    case alongEdge(edgeID: String, fromNodeID: String, toNodeID: String, progress: Double)
}

enum TrackingConfidence: Equatable, Sendable {
    case high      // アンカー確定直後、または交差点回転がグラフと一致した直後
    case medium    // 直線廊下を歩数のみで進行中
    case uncertain // 予想距離を大幅に超過しても期待される曲がり角が検知されない（逸脱の疑い）
}
```

---

## 4. 画面・UI とのつながり（過信しない案内体験）

1. **自由な青丸（Blue Dot）ではなく「進行中ステップ・エッジの強調」で示す**
   - 屋内では GPS のような誤差円付き青丸を出さず、現在進行中の `walking_path`（廊下セグメント）と通過済みチェックポイント（`indoor_node`）のハイライトで現在位置を表す。
2. **フロア切替は「サジェスト＋ワンタップ確定」を基本とする**
   - 経路上の歩行距離が階段・EV ノード（`node_kind: transition`）の手前閾値に達したら、`onApproachFloorTransition` を発火して「階段で 2F へ移動」チップを強調表示し、ワンタップ（または移動後の QR 読取）で 2F の SVG フロアマップへ切り替える。
3. **信頼度低下（`uncertain`）時の誠実なフォールバック**
   - 廊下の長さを大きく超えて歩いても曲がり角が一致しない場合は、勝手に別ルートへ飛ばさず、「現在地を確認できません。近くの部屋を選ぶか QR を読み取ってください」と手動補正導線（`onDeviationDetected`）を提示する。

---

## 5. 段階的な検証・導入ステップ（卒業研究 2 年計画との整合）

1. **Step 1（v1.0 / M1〜M4）：基準データと手動・入口起点の屋内経路案内を完成させる**
   - `docs/v1.0-scope.md` に従い、まずはセンサー推定なしで「屋外 GPS ＋ 正式入口接続 ＋ 屋内 SVG マップとステップ案内（手動進行）」をリリース品質で完成させる。
2. **Step 2（v1.0 後・Phase 1 前半）：`IndoorGraphTracker` の純粋ロジック実装と単体リプレイ検証**
   - 実機センサーをつなぐ前に、`NexusTests` 上で `MapGeoJSON`（`mb` / `ptb` の屋内グラフ）と模擬イベント列（`[anchorConfirmed, stepAdvanced(5.0), turnDetected(85.0), ...]`）を入力し、期待どおりにステップ進行・誤差リセット・逸脱判定が動くことを単体テストで証明する。
3. **Step 3（Phase 1 後半）：iOS 実機での `CMPedometer` / `CMDeviceMotion` アダプタ接続と校舎内実証**
   - `apps/nexus-ios/` の Route 機能にセンサーアダプタを注入し、実際の校舎（`mb` / `ptb`）を歩いて「歩数のみ」「歩数＋相対回転角」「QR チェックポイント併用」の到着率・ステップ一致率を比較計測する（卒業研究の評価実験データとしても活用可能）。
4. **Step 4（将来）：Android 版への同一アルゴリズム展開**
   - Step 2 で確立した `IndoorPositionEvent` → `IndoorTrackingState` の状態マシンとテストケースをそのまま Kotlin へ移植し、`TYPE_STEP_DETECTOR` / `TYPE_GAME_ROTATION_VECTOR` を接続する。
