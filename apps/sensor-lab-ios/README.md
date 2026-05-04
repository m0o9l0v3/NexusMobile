# Nexus Sensor Lab

## 概要
**Nexus Sensor Lab** は、オープンキャンパス向け複合型アプリ「Nexus」に組み込む前段階の **Phase 0 技術検証アプリ** です。iPhone の `CMAltimeter` を使い、屋内階層移動（上昇/下降/停止）を検知するためのセンサー取得とログ分析を行います。

## 目的
- 気圧センサー値（気圧・相対高度）のリアルタイム取得
- 移動平均フィルタによる高度ノイズ低減
- フィルタ後高度差分に基づく昇降状態判定
- CSVログ出力による実地検証データの蓄積

## 使用技術
- Swift
- SwiftUI
- CoreMotion (`CMAltimeter`)
- UIKit (`UIActivityViewController`) ※CSV共有シート

## 実機検証の必要性
`CMAltimeter` は iOS シミュレーターで正しく動作しない場合があるため、**iPhone 実機での検証が必須**です。

## 操作方法
1. アプリ起動後、自動的にセンサー監視を開始
2. `Start Recording` でログ記録開始
3. `Stop Recording` で記録停止
4. `Export CSV` でCSVを共有シートから保存
5. `Clear Logs` でメモリ上ログを消去

## CSV出力形式
ヘッダー:
```csv
timestamp,pressure,relativeAltitude,filteredAltitude,state
```

各カラム:
- `timestamp`: ISO8601 (ミリ秒付き)
- `pressure`: hPa
- `relativeAltitude`: m
- `filteredAltitude`: m（移動平均後）
- `state`: `stationary` / `ascending` / `descending`

## Nexus本体へ移植予定のロジック
- `Core/MovingAverageFilter.swift`: 相対高度の移動平均フィルタ
- `Core/MotionStateDetector.swift`: 上昇/下降/停止判定ロジック
- `Services/AltimeterService.swift`: センサー取得ライフサイクル管理
- `Services/CSVExportService.swift`: 検証ログのCSV変換

## 注意点
- 本アプリは検証専用（Phase 0）であり本番UXは対象外
- 気圧変動・端末姿勢・移動速度により判定が揺れるため、`windowSize` と `threshold` の現地チューニングを推奨
- `CMAltimeter` 非対応端末では利用不可メッセージを表示


## 事前レビューで修正したポイント（ビルド前）
- `project.pbxproj` の識別子形式をXcode互換の固定長に修正し、プロジェクト読み込み失敗リスクを低減
- CSVの数値フォーマットを `en_US_POSIX` + 固定小数点に統一（ロケール依存の `,` 小数点混入を防止）
- センサー監視停止時にフィルタ状態・前回高度差分・記録状態をリセットし、再開時の判定ドリフトを抑制

## CMAltimeter / 権限に関する補足
- `CMAltimeter` の相対高度取得は通常、明示的な権限ダイアログを必要としません
- ただし端末・OS状態により値更新が不安定になるケースがあるため、`Sensor Status` とエラーメッセージを必ず確認してください
