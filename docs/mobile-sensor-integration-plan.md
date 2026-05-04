# Mobile Sensor Integration Plan

## 目的
React Native / Expo 版 Nexus で将来 CoreMotion / CMAltimeter を統合するための設計方針。

## 共有データ型
```ts
export type EstimatedIndoorPosition = {
  floor: string;
  x?: number;
  y?: number;
  confidence: number;
  source: 'manual' | 'barometer' | 'sensor-fusion' | 'admin';
  updatedAt: string;
};
```

## floor推定の扱い
- floor は `1F`, `2F` のような表示値と内部IDのマッピングを持つ。
- confidence が閾値未満の場合は UI に「推定中」を表示する。

## センサーPoC接続
- `apps/sensor-lab-ios` で生成する CSV を変換して replay 可能な JSON にする。
- mobile-ios 側で mock provider として注入し、UI/経路選択を検証する。

## ネイティブモジュール化方針
- Phase 1.5 では Expo Managed を維持。
- 以下を満たした場合のみ prebuild/bare を検討:
  - バロメータ/モーションの高頻度ストリームが Expo API で不足
  - バッテリー制御要件で native 実装が必要
  - App Store 審査向けに詳細な権限制御が必要
