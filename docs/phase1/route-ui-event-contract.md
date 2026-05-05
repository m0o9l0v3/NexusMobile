# Phase 1 ルート表示UI強化: イベント契約書（関数定義一覧）

## 目的
本書は、Route UI Enhancement（Phase 1）で利用するイベント関数を、
「イベントID」「イベントトリガー」などの項目単位で統一管理するための設計ドキュメントです。

---

## 共通フォーマット
各イベント関数は以下の項目で定義します。

- **イベントID**
- **イベント名（関数名）**
- **カテゴリ**（UI / Domain / System）
- **トリガー画面**（A〜E）
- **イベントトリガー**（User / Location / API / Timer）
- **事前条件**
- **ペイロード**
- **参照状態（State Read）**
- **更新状態（State Write）**
- **副作用（Side Effects）**
- **成功条件**
- **失敗モード**
- **エラーハンドリング**
- **関連状態遷移**
- **優先度**（Must / Should / Nice）

---

## 画面A: 検索・条件入力（Route Search）

### NAV-SEARCH-001
- **イベント名（関数名）**: `onSubmitSearch(fromId, toId)`
- **カテゴリ**: UI
- **トリガー画面**: A
- **イベントトリガー**: User（検索ボタン押下）
- **事前条件**: `from` と `to` が有効
- **ペイロード**:
  - `fromId: string`（必須）
  - `toId: string`（必須）
- **参照状態**: `search.from`, `search.to`, `search.isValid`
- **更新状態**: `flowState = searching`
- **副作用**: ルート候補探索API実行
- **成功条件**: 候補取得成功で `SEARCH_SUCCESS`
- **失敗モード**: API失敗 / 候補0件
- **エラーハンドリング**: `flowState = error`
- **関連状態遷移**: `idle -> searching -> options|error`
- **優先度**: Must

### NAV-SEARCH-002
- **イベント名（関数名）**: `onSuggestionSelect(field, poi)`
- **カテゴリ**: UI
- **トリガー画面**: A
- **イベントトリガー**: User（候補タップ）
- **事前条件**: 候補リスト表示中
- **ペイロード**:
  - `field: "from" | "to"`（必須）
  - `poi: { id: string, name: string, floor?: string }`（必須）
- **参照状態**: `search.focusField`
- **更新状態**: `search.from` または `search.to`
- **副作用**: バリデーション再計算
- **成功条件**: 入力欄反映完了
- **失敗モード**: POI不正データ
- **エラーハンドリング**: フォールバックで手入力維持
- **関連状態遷移**: 画面内状態更新のみ
- **優先度**: Must

---

## 画面B: ルート候補選択（Route Options）

### NAV-OPTION-001
- **イベント名（関数名）**: `onSelectRoute(routeId)`
- **カテゴリ**: UI
- **トリガー画面**: B
- **イベントトリガー**: User（候補カードタップ）
- **事前条件**: `candidateRoutes.length > 0`
- **ペイロード**:
  - `routeId: string`（必須）
- **参照状態**: `candidateRoutes`
- **更新状態**: `selectedRouteId = routeId`
- **副作用**: プレビュー軽量データ準備
- **成功条件**: 選択状態ハイライト
- **失敗モード**: routeId不一致
- **エラーハンドリング**: デフォルト候補へ戻す
- **関連状態遷移**: `options`内更新
- **優先度**: Must

### NAV-OPTION-002
- **イベント名（関数名）**: `onConfirmRoute()`
- **カテゴリ**: UI
- **トリガー画面**: B
- **イベントトリガー**: User（案内開始前の決定押下）
- **事前条件**: `selectedRouteId != null`
- **ペイロード**: なし
- **参照状態**: `selectedRouteId`, `candidateRoutes`
- **更新状態**: `selectedRoute`, `flowState = preview`
- **副作用**: プレビュー初期化
- **成功条件**: 画面C遷移
- **失敗モード**: ルート未選択
- **エラーハンドリング**: CTA無効維持
- **関連状態遷移**: `options -> preview`
- **優先度**: Must

---

## 画面C: ルートプレビュー（Preview）

### NAV-PREVIEW-001
- **イベント名（関数名）**: `onBottomSheetChange(state)`
- **カテゴリ**: UI
- **トリガー画面**: C
- **イベントトリガー**: User（スワイプ）
- **事前条件**: Bottom Sheet表示中
- **ペイロード**:
  - `state: "collapsed" | "half" | "expanded"`（必須）
- **参照状態**: `bottomSheetState`
- **更新状態**: `bottomSheetState = state`
- **副作用**: なし
- **成功条件**: 指定状態で表示
- **失敗モード**: 不正state
- **エラーハンドリング**: `collapsed`へフォールバック
- **関連状態遷移**: UIサブマシン内遷移
- **優先度**: Must

### NAV-PREVIEW-002
- **イベント名（関数名）**: `onPressStartNavigation()`
- **カテゴリ**: UI
- **トリガー画面**: C
- **イベントトリガー**: User（開始ボタン押下）
- **事前条件**: `selectedRoute` が存在
- **ペイロード**: なし
- **参照状態**: `selectedRoute`
- **更新状態**:
  - `navigationMode = navigating`
  - `currentStepIndex = 0`
  - `flowState = navigating`
- **副作用**: 位置追跡開始
- **成功条件**: 画面D遷移
- **失敗モード**: 位置権限不足
- **エラーハンドリング**: 権限案内表示・開始保留
- **関連状態遷移**: `preview -> navigating`
- **優先度**: Must

---

## 画面D: ナビゲーション中（Navigating）

### NAV-STEP-001
- **イベント名（関数名）**: `onNavigationTick(position)`
- **カテゴリ**: Domain
- **トリガー画面**: D
- **イベントトリガー**: Location（定期更新）
- **事前条件**: `navigationMode = navigating`
- **ペイロード**:
  - `position: { x: number, y: number, floor: string, accuracy?: number }`（必須）
- **参照状態**: `currentStepIndex`, `route.steps`, `route.segments`
- **更新状態**:
  - `currentPosition`
  - `remainingDistance`
  - `remainingDuration`
- **副作用**: ステップ境界判定
- **成功条件**: 残距離/残時間が更新
- **失敗モード**: 位置異常値
- **エラーハンドリング**: 当該tick破棄
- **関連状態遷移**: `guiding`継続
- **優先度**: Must

### NAV-STEP-002
- **イベント名（関数名）**: `onStepBoundaryCrossed(nextStepIndex)`
- **カテゴリ**: Domain
- **トリガー画面**: D
- **イベントトリガー**: Location（境界到達）
- **事前条件**: `nextStepIndex > currentStepIndex`
- **ペイロード**:
  - `nextStepIndex: number`（必須）
- **参照状態**: `currentStepIndex`
- **更新状態**: `currentStepIndex = nextStepIndex`
- **副作用**: 指示文更新、進捗更新
- **成功条件**: CurrentStepIndicatorが次指示へ
- **失敗モード**: ノイズによる誤進行
- **エラーハンドリング**: ヒステリシス適用
- **関連状態遷移**: `guiding`継続
- **優先度**: Must

### NAV-FLOOR-001
- **イベント名（関数名）**: `onApproachFloorTransition(transitionId, distanceToTransition)`
- **カテゴリ**: Domain
- **トリガー画面**: D
- **イベントトリガー**: Location（跨ぎ手前閾値）
- **事前条件**: 次跨ぎステップが存在
- **ペイロード**:
  - `transitionId: string`（必須）
  - `distanceToTransition: number`（必須）
- **参照状態**: `route.floorTransitions`, `currentStepIndex`
- **更新状態**: `nextTransition = transitionId`
- **副作用**: FloorTransitionChip強調
- **成功条件**: 予告表示の視認
- **失敗モード**: 多重通知
- **エラーハンドリング**: 同一transition通知を抑止
- **関連状態遷移**: `guiding -> approaching_transition`
- **優先度**: Must

### NAV-FLOOR-002
- **イベント名（関数名）**: `onFloorTransitionCompleted(newFloor)`
- **カテゴリ**: Domain
- **トリガー画面**: D
- **イベントトリガー**: Location（跨ぎ完了判定）
- **事前条件**: `transitioning_floor` 状態
- **ペイロード**:
  - `newFloor: string`（必須）
- **参照状態**: `isAutoFloorSwitchEnabled`, `currentFloor`
- **更新状態**:
  - `currentFloor = newFloor`
  - auto ON時 `visibleFloor = newFloor`
- **副作用**: フロア表示同期
- **成功条件**: フロア不一致解消
- **失敗モード**: フロア識別失敗
- **エラーハンドリング**: 手動フロア選択誘導
- **関連状態遷移**: `transitioning_floor -> guiding`
- **優先度**: Must

### NAV-OFFROUTE-001
- **イベント名（関数名）**: `onDeviationDetected(distanceFromRoute)`
- **カテゴリ**: Domain
- **トリガー画面**: D
- **イベントトリガー**: Location（逸脱閾値超過）
- **事前条件**: `guiding` 状態
- **ペイロード**:
  - `distanceFromRoute: number`（必須）
- **参照状態**: `routeGeometry`, `currentPosition`
- **更新状態**: `navigatingSubState = off_route`
- **副作用**: 逸脱バナー表示、再計算導線
- **成功条件**: 復帰手段提示
- **失敗モード**: 過検知
- **エラーハンドリング**: 連続検知時にクールダウン
- **関連状態遷移**: `guiding -> off_route`
- **優先度**: Should

### NAV-ARRIVE-001
- **イベント名（関数名）**: `onArrivalDetected(arrivalPoiId)`
- **カテゴリ**: Domain
- **トリガー画面**: D
- **イベントトリガー**: Location（到着判定）
- **事前条件**: 最終ステップ完了 + 到着半径内
- **ペイロード**:
  - `arrivalPoiId: string`（必須）
- **参照状態**: `destination`, `currentStepIndex`
- **更新状態**:
  - `navigationMode = arrived`
  - `flowState = arrived`
- **副作用**: 到着サマリー生成
- **成功条件**: 画面E遷移
- **失敗モード**: 早着誤判定
- **エラーハンドリング**: 判定条件の再確認（複合条件）
- **関連状態遷移**: `navigating -> arrived`
- **優先度**: Must

---

## 画面E: 到着（Arrived）

### NAV-ARRIVE-002
- **イベント名（関数名）**: `onPressSearchNextDestination()`
- **カテゴリ**: UI
- **トリガー画面**: E
- **イベントトリガー**: User（次を探すボタン押下）
- **事前条件**: 到着画面表示中
- **ペイロード**: なし
- **参照状態**: `routeCompletionSummary`
- **更新状態**: ルート関連状態を初期化し `flowState = idle`
- **副作用**: 検索画面へ遷移
- **成功条件**: 画面A遷移
- **失敗モード**: 状態クリア失敗
- **エラーハンドリング**: 強制初期化
- **関連状態遷移**: `arrived -> idle`
- **優先度**: Must

---

## 付録: 優先実装イベント（Phase 1 Must）

1. `onSubmitSearch`
2. `onSelectRoute`
3. `onConfirmRoute`
4. `onPressStartNavigation`
5. `onNavigationTick`
6. `onStepBoundaryCrossed`
7. `onApproachFloorTransition`
8. `onFloorTransitionCompleted`
9. `onArrivalDetected`

