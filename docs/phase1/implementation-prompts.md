# Phase 1 ルート表示UI強化: 段階的実装プロンプト集

## 使い方
- 以下のプロンプトは、設計書から実装へ段階的に移すための実行用テンプレートです。
- 各ステップは「そのステップだけ」を実装対象にし、完了条件を満たしたら次へ進みます。
- すべてのステップで、実装後に変更ファイル・テスト結果・未解決リスクを報告してください。

---

## Step 0: 現状把握と差分確認（準備）

### プロンプト
```text
あなたはシニアフロントエンドエンジニアです。

以下のドキュメントを読み、実装前の差分確認だけを行ってください。
- docs/phase1/route-ui-event-contract.md
- docs/phase1/route-ui-next-tasks.md
- apps/public-api/Data/phase1-navigation.json

やること:
1) 既存データ構造とイベント契約の差分を列挙
2) 実装に必須な追加フィールドを優先度付きで提案
3) 影響ファイル候補を列挙

制約:
- コード変更はしない
- 推測で断定しない
- 最後に「このステップでは未実装」であることを明記
```

### 完了条件
- 追加すべきデータフィールドと影響範囲が明確になっている。

---

## Step 1: ナビゲーションデータスキーマ拡張（最小）

### プロンプト
```text
あなたはシニアフロントエンドエンジニアです。

目的:
Phase 1ナビUI実装のため、apps/public-api/Data/phase1-navigation.json を最小拡張してください。

必須追加:
- routes[].segments[]
- routes[].steps[]
- routes[].floorTransitions[]

要件:
1) 既存フィールドとの後方互換を維持
2) entrance-to-library 系ルートでフロア跨ぎを表現
3) step と transition の対応が分かるID/Indexを持たせる
4) JSONとして妥当な状態にする

出力:
- 変更したJSONの意図
- 追加フィールド一覧
- サンプル1ルートの読み方
```

### 完了条件
- JSONのみで step進行とフロア跨ぎ判定ができる。

---

## Step 2: Route型・パーサーの追従実装

### プロンプト
```text
あなたはTypeScript/Reactの実装担当です。

目的:
Step 1で拡張した navigation JSON を安全に扱うため、型定義と読み込み処理を更新してください。

要件:
1) Route / Segment / Step / FloorTransition の型を追加
2) 既存データ読み込み処理を壊さず拡張
3) 不正データ時のフォールバック方針を明示
4) 型エラー・Lintエラーを解消

制約:
- UIはまだ変更しない
- テスト可能なら最低限のユニットテストを追加

出力:
- 変更ファイル
- 型の要点
- 後方互換の担保方法
```

### 完了条件
- 新旧ルートデータを同じ読込経路で扱える。

---

## Step 3: イベント基盤（Reducer/State Machine）実装

### プロンプト
```text
あなたは状態管理設計に強いフロントエンドエンジニアです。

目的:
route-ui-event-contract.md に沿って、イベント駆動の状態更新基盤を実装してください。

必須イベント:
- onSubmitSearch
- onSelectRoute
- onConfirmRoute
- onPressStartNavigation
- onNavigationTick
- onStepBoundaryCrossed
- onApproachFloorTransition
- onFloorTransitionCompleted
- onArrivalDetected

要件:
1) 状態遷移ガードをコードで表現
2) stepIndex単調増加を保証
3) floor transition 完了時の floor同期を保証
4) arriving 判定は複合条件で実装

制約:
- 見た目の大改修はしない
- デバッグしやすいよう event log を残せる構造にする
```

### 完了条件
- 主要イベントで想定どおり状態遷移する。

---

## Step 4: プレビューUI（画面C）実装

### プロンプト
```text
あなたはモバイルUX重視のUI実装担当です。

目的:
画面C（Preview）で、次情報を最小構成で表示してください。
- RouteSummary（総距離/総時間/跨ぎ回数）
- BottomSheet collapsed/half/expanded
- Start Navigation導線

要件:
1) 既存地図表示を壊さない
2) BottomSheet状態を state と同期
3) selectedRoute 未設定時のガード

制約:
- まずはデザイン最適化より情報表示の正しさを優先
```

### 完了条件
- プレビューで全体把握と開始導線が成立する。

---

## Step 5: ナビ中UI（画面D）実装

### プロンプト
```text
あなたはナビゲーションUI実装担当です。

目的:
画面D（Navigating）で、現在行動と進捗が即座に分かるUIを実装してください。

必須UI:
- CurrentStepIndicator
- DistanceTimeBadge（残距離/残時間）
- FloorTransitionChip（接近時のみ強調）

要件:
1) onNavigationTick と onStepBoundaryCrossed で表示が更新
2) transition接近/完了で表示が連動
3) 到着判定で arrived 状態へ遷移

制約:
- パフォーマンスを意識し、不要再レンダリングを抑制
```

### 完了条件
- 歩行中に「次に何をするか」が常に分かる。

---

## Step 6: Given/When/Then テスト整備

### プロンプト
```text
あなたはQA自動化担当です。

目的:
状態遷移図に対応するテストを Given/When/Then 形式で整備してください。

対象:
- idle -> searching -> options -> preview -> navigating -> arrived
- guiding -> approaching_transition -> transitioning_floor -> guiding
- guiding -> off_route -> guiding
- guiding -> paused_confirm -> guiding|preview

要件:
1) 正常系・境界系・異常系を含める
2) stepIndex単調増加ガードを検証
3) arrival複合条件の誤判定防止を検証
```

### 完了条件
- 主要遷移が自動テストで再現できる。

---

## Step 7: UI文言・表示ルールの固定反映

### プロンプト
```text
あなたはUXライティングとUI実装の担当です。

目的:
距離・時間・フロア・通知文言の表示ルールを実装へ反映してください。

ルール:
- 距離: m / km の統一
- 時間: 分ベース（必要時のみ時間+分）
- フロア: B1/1F/2F 形式統一
- 通知: 跨ぎ/逸脱/到着テンプレート適用

要件:
1) 画面C/D/Eで文言ゆれを無くす
2) 文言定義を1箇所に集約
```

### 完了条件
- 全画面で表示ルールが統一される。

---

## Step 8: 最小Analytics実装

### プロンプト
```text
あなたはプロダクト分析実装担当です。

目的:
Phase 1の効果測定に必要な最小Analyticsを実装してください。

必須イベント:
- route_search_submitted
- route_navigation_started
- route_arrived
- floor_transition_notice_shown
- route_deviation_detected

要件:
1) 発火条件をイベント契約に合わせる
2) payload最小項目（routeId, fromSpotId, toSpotId, floor等）を統一
3) 二重送信を防止
```

### 完了条件
- 主要KPIを計測できるログが安定取得できる。

---

## Step 9: 仕上げ（リファクタ + ドキュメント更新）

### プロンプト
```text
あなたは最終仕上げ担当です。

目的:
Phase 1実装を安全にマージできる状態に整えてください。

要件:
1) 不要コード・暫定ログを整理
2) docs/phase1 の仕様との差分を更新
3) 既知の制約・今後対応を明記
4) テスト結果をまとめる
```

### 完了条件
- 実装と仕様の整合が取れ、次フェーズへ引き継げる。
