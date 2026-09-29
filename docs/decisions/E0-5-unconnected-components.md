# Historical implementation paths

> The `mobile-ios` component paths below described the retired Expo implementation deleted on 2026-09-29. This decision preserves its historical evaluation; it does not direct new work to those paths.

# E0-5: 未接続コンポーネントの処遇を決める

- 移行元ID: E0-5 / 区分: E0 / 根拠: v1.0workitemsboard.md（GitLabコード 1e5e358 時点の棚卸し）
- 判断日: 2026-08-30
- 判断者: リポジトリオーナー（技術的意思決定者）

> **後続決定による更新:** 本文は E0-5 判断時点の技術調査と開発順序を記録したものである。「Web先行・iOS追随」は技術検証上の順序であり、参加者体験の正式な提供元を定める製品方針ではない。[Work item #7](https://gitlab.com/11h27m/nexus-mobile/-/work_items/7) により、v1.0 の参加者向けアプリ機能は iOS に限定し、`web/` はイベント告知 LP へ再構成する方針が確定した。Web コンポーネントの扱いは [Work item #81](https://gitlab.com/11h27m/nexus-mobile/-/work_items/81) の棚卸し結果を優先する。

## 対象と調査結果

いずれもコード自体は完成済みで、デザインシステム（トークン・既存コンポーネント）に準拠している。呼び出し元（画面/ルーティング）から参照されていないため未接続の状態だった。

| コンポーネント | パス | 状態 | 備考 |
|---|---|---|---|
| CongestionFilter (Web) | `web/src/app/components/CongestionFilter.tsx` | 未接続 | `CongestionBadge` を利用したアニメーション付き混雑フィルタUI。`MapScreen.tsx` から呼ばれていない |
| FloorSwitch (mobile-ios) | `apps/mobile-ios/src/components/map/FloorSwitch.tsx` | 未接続 | Web版 `FloorSwitch.tsx`（`MapScreen.tsx` で使用中）のRN移植版 |
| CongestionFilter (mobile-ios) | `apps/mobile-ios/src/components/map/CongestionFilter.tsx` | 未接続 | Web版と同等機能のRN移植版 |
| RouteStepChip (mobile-ios) | `apps/mobile-ios/src/components/map/RouteStepChip.tsx` | 未接続 | Web版 `RouteStepChip.tsx`（`BottomSheet.tsx` 等で使用中）と同等のRN版 |
| MapHeroCard (mobile-ios) | `apps/mobile-ios/src/components/MapHeroCard.tsx` | 未接続 | Web版 `MapHeroCard.tsx`（`HomeScreen.tsx` で使用中）と同等のRN版 |
| EventsPage (admin-web) | `apps/admin-web/src/pages/events/EventsPage.tsx`（+ 付随する `EventQrIssuesPage.tsx`） | 未接続 | 一覧・Delete/Publish/QR導線は実装済みだが、遷移先の New/Edit 画面は存在しない。`EventQrIssuesPage.tsx` は実装済みだがルート未登録。`apps/admin-web/src/App.tsx` の `/events` は `Placeholder`（工事中表示）のみで、`/events/new`・`/events/:id/edit`・`/events/:id/qr-issues` は未定義 |

## E0-5 判断時点の採用方針

**対象コンポーネントは「接続」を採用し、削除は採用しない。**

この判断は、各コンポーネントに再利用価値があるという技術評価を記録したものである。#7 以降は、iOS・admin-web の接続判断を維持し、Web の `CongestionFilter` を現在の参加者向け画面へ接続する判断は撤回する。Web 資産は #81 で LP への再利用・置換・削除・保全を判断する。

### 理由

- E0-5 の判断時点では、対象はいずれも実装が完成しており、既存の型・デザイントークン・命名規約に沿っているため、接続可能な品質と評価した。
- 廃止を示す痕跡（コメントアウト、TODO削除メモ、置き換え先コンポーネントの存在など）が見当たらない。
- E0-5 の判断時点では、Web版のPWAで同等の3コンポーネント（FloorSwitch / RouteStepChip / MapHeroCard）が接続・稼働しており、mobile-ios側の対応コンポーネントを接続する技術的根拠として参照した。#7 により正式な参加者向け提供元が iOS に限定された後も、iOS 側コンポーネントの評価は有効である。
- `EventsPage.tsx` の一覧・Delete/Publish/QR導線は配線漏れの可能性が高い（実装済みなのにプレースホルダー表示のまま）。ただし New/Edit 画面は未実装であり、`EventQrIssuesPage.tsx` もルート未登録のため、単純な配線漏れではなく画面新規実装とルート追加が必要。いずれも削除する理由がない。

### 却下した選択肢

- **削除する**: いずれも動作する完成コードであり、再実装コストの方が高い。却下。
- **判断を保留する**: Issueの完了条件（後続Issueが追加確認なしで着手できる状態にする）を満たさないため却下。

## 後続作業（本Issueのスコープ外）

本Issueの完了条件は方針決定の記録であり、実装（配線）は別Issueとする。

1. `web/src/app/components/CongestionFilter.tsx` は現在の `MapScreen.tsx` へ接続せず、#81 で LP への再利用・置換・削除・保全を判断する。
2. `apps/mobile-ios` のMap画面・Home画面に `FloorSwitch` / `CongestionFilter` / `RouteStepChip` / `MapHeroCard` を接続する（mobile-ios側の画面構成の調査が別途必要）。
3. `apps/admin-web/src/App.tsx` の `/events` ルートを `Placeholder` から `EventsPage` に差し替え、`/events/new`・`/events/:id/edit`・`/events/:id/qr-issues` を追加配線する。New/Edit 画面は現時点で未実装のため新規実装が必要で、`EventQrIssuesPage` はルート登録のみで足りる。

iOS・admin-web の後続Issueは本ドキュメントの技術評価を前提として着手できる。Web の後続作業は #81 の製品方針と棚卸し結果を前提とする。
