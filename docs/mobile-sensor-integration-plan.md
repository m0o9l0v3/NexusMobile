# Sensor Lab から SwiftUI アプリへの統合計画

## 状態

計画段階です。Sensor Lab の高度推定を製品へ移す場合の実装先は `apps/nexus-ios/` です。旧Expoアプリ `apps/mobile-ios/` は2026-09-29に削除しました。

## 目的

`apps/sensor-lab-ios/` で検証した CoreMotion / CMAltimeter の処理を、必要性と受入条件を確認したうえでSwiftUIアプリへ統合します。Sensor Lab自体は独立した検証アプリとして維持し、無条件に本番アプリへ取り込まないでください。

## 統合境界

- Swift の型・protocol として屋内位置推定結果を表現し、Home / Map / 案内 / 探すの画面モデルからセンサー実装を直接参照させない。
- CSV / replay JSON はテスト・検証専用とし、本番データや正規位置情報として扱わない。
- 推定フロアは canonical floor ID と表示名を分ける。フロアの自動判定が不確かな場合は「推定中」または未確定状態を示し、地図上の階や経路を誤って確定しない。
- 実機の位置情報権限が拒否された場合、手動での階・出発地選択を維持する。
- GPS経路・階移動の製品受入は #80/#87、Indoor map / floor contract は #36/#39/#42 の担当範囲と整合させる。

## 段階

1. Sensor Lab の測定条件・CSV provenance・精度を評価する。
2. Unit-testable な Swift protocol と replay fixture を `apps/nexus-ios/NexusTests/` に追加し、機器なしで状態遷移を検証する。
3. 実機で測位の精度、階判定の誤り、取得間隔、電池消費を測定する。
4. 計測結果が製品要件を満たす場合に限り、SwiftUI アプリの Map / Route 状態へ接続する。
5. 結果と限界を #80/#87 に記録する。未計測のバリアフリーや自動階判定を保証しない。

## 完了条件

- 実測方法・端末・OS・試験時間・期待値・失敗基準を記録する。
- replay test と実機検証の結果を別々に記録する。
- 誤った推定時に架空の位置・階を表示せず、手動操作へ戻せる。
- Sensor Labのコードを本番へコピーするだけで完了扱いにしない。
