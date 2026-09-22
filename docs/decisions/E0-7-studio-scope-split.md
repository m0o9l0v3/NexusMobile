# E0-7: 管理ポータルを Nexus Studio へ移し、E2・E7 の担当を分割する

- 移行元ID: E0-7 / 区分: E0 / 根拠: 2026-09-22 のリポジトリオーナーの判断（Nexus Studio 側の決定記録 D-11・D-17・D-18・D-19）
- 判断日: 2026-09-22
- 判断者: リポジトリオーナー（技術的意思決定者）
- 状態: 採用
- 関連リポジトリ: [nexusstudio](https://gitlab.com/11h27m/nexusstudio)（`docs/決定事項/` に Studio 側の決定記録）

## 採用方針

**管理ポータルの責務を、本リポジトリの `apps/admin-web` から別プロダクト「Nexus Studio」へ移す。**

1. **`apps/admin-web` は完全に排除する。** 段階的な機能移管ではなく、Nexus Studio が同等以上の機能を提供した時点で削除する。
2. **`epic::E7`（管理ポータル）の担当は Nexus Studio とする。**
3. **`epic::E2` を分割する。** MapDataset の draft・validation までは本リポジトリ、**publish / rollback は Nexus Studio**、公開配信と iOS 側の取得・キャッシュ・版更新は本リポジトリが担当する。
4. Nexus Studio は別リポジトリで開発し、本リポジトリとは**版付きの契約**（OpenAPI、JSON Schema、決定記録）でのみ結合する。

## 理由

- **本リポジトリが肥大化している。** 参加者向け iOS、Web LP、2本の API、管理ポータル、センサー検証アプリ、地図変換 CLI を単一リポジトリで抱えている。
- **Nexus Studio は v1.0 以降も成長が見込まれる。** Nexus AI Ecosystem の発展に伴い、管理・制作環境の規模は拡大する想定であり、参加者向けアプリとライフサイクルを分けたほうが扱いやすい。
- **`apps/admin-web` に失うものがほとんどない。** 到達可能な4画面（Dashboard / CrowdAnalysis / QRIssue / Logs）はいずれもハードコードされた定数のみで描画しており、API 呼び出しが1件も無い。実 API へ接続済みの `EventsPage.tsx` / `EventQrIssuesPage.tsx` は `App.tsx` から参照されておらず到達できない（[E0-5](E0-5-unconnected-components.md) 参照）。
- Nexus Studio 側では PC ブラウザ向けの UI 設計・承認が既に進んでいる。

## 責務の境界

| 操作 | 担当 |
|---|---|
| イベント・開催情報・カテゴリ・Spot・地図の**編集と公開** | **Nexus Studio のみ** |
| 参加者向けの**読み取り**（iOS・Web LP） | **`apps/public-api` のみ** |
| QR 発行・ワンタイムコード・参加者ログ閲覧（hidden beta） | `apps/admin-api`（縮小して残置） |

[`docs/api-foundation.md`](../api-foundation.md) が定める「admin＝書き込み、public＝参加者向け読み取り」の境界は、プロダクトが分かれた後も維持する。**Nexus Studio は参加者向けの配信エンドポイントを持たない。**

## `apps/admin-api` への影響

管理画面が Nexus Studio へ移ると、`apps/admin-api` に残る責務は次だけになる。

| 現行の責務 | 移行後 |
|---|---|
| 管理者認証（設定ファイル上の単一固定資格情報） | **廃止**。Nexus Studio 側で個別の管理者アカウントを実装する |
| spots / events / oc-days の CRUD | **廃止**。Nexus Studio の編集・公開モデルへ |
| MapDataset モデル・validator・draft API | Nexus Studio へ移植する（成果物は保全する） |
| QR issue / one-time code | **残置**（v1.0 hidden beta） |
| `admin/logs/recent`・監査チェーン検証 | **残置**（参加者ログ `visit_logs` の閲覧） |

**移行期間中に二重書き込みを作らない。** Nexus Studio が各責務を引き取った時点で、`apps/admin-api` の該当エンドポイントを同じ変更単位で無効化する。

## E2 分割の詳細

| Work item | 内容 | 担当 |
|---|---|---|
| [#17](https://gitlab.com/11h27m/nexus-mobile/-/work_items/17) `[E2-1]` MapDataset エンティティ | 完了 | 本リポジトリ（成果は Studio へ移植） |
| [#18](https://gitlab.com/11h27m/nexus-mobile/-/work_items/18) `[E2-2]` validator | 完了 | 同上 |
| [#19](https://gitlab.com/11h27m/nexus-mobile/-/work_items/19) `[E2-3]` draft 作成・更新・検証 | 完了 | 同上 |
| [#20](https://gitlab.com/11h27m/nexus-mobile/-/work_items/20) `[E2-4]` **publish / rollback** | 未着手 | **Nexus Studio へ移管** |
| [#23](https://gitlab.com/11h27m/nexus-mobile/-/work_items/23) `[E2-5]` 公開配信エンドポイント | 未着手 | 本リポジトリ。**依存先を #20 から Studio の公開基盤へ付け替える** |
| [#21](https://gitlab.com/11h27m/nexus-mobile/-/work_items/21) `[E2-6]` NavigationDataStore 置換 | 未着手 | 本リポジトリ |
| [#22](https://gitlab.com/11h27m/nexus-mobile/-/work_items/22) `[E2-7]` iOS の取得・キャッシュ・版更新 | 未着手 | 本リポジトリ |

publish / rollback を Nexus Studio に置く理由は、**イベントと地図を整合する組み合わせで公開する**ためである。公開の原子性が2つのサービスにまたがると、「部分反映を作らない」という公開方針を満たしにくい。

## E7 Work item の扱い

| Work item | 措置 |
|---|---|
| [#55](https://gitlab.com/11h27m/nexus-mobile/-/work_items/55) ログイン画面と認証ガード | Nexus Studio へ移管 |
| [#56](https://gitlab.com/11h27m/nexus-mobile/-/work_items/56) トークン保管方式を見直す | **廃止**（Cookie 方式の採用で前提が消滅） |
| [#57](https://gitlab.com/11h27m/nexus-mobile/-/work_items/57) スポット CRUD 画面 | Nexus Studio へ移管 |
| [#58](https://gitlab.com/11h27m/nexus-mobile/-/work_items/58) 開催日管理画面 | Nexus Studio へ移管 |
| [#59](https://gitlab.com/11h27m/nexus-mobile/-/work_items/59) Dashboard を実 API へ接続 | Nexus Studio へ移管（Overview として再定義） |
| [#60](https://gitlab.com/11h27m/nexus-mobile/-/work_items/60) `EventsPage.tsx` をルーティングに接続 | **廃止**（admin-web 排除により前提が消滅） |
| [#61](https://gitlab.com/11h27m/nexus-mobile/-/work_items/61) Logs を実 API へ接続 | Nexus Studio へ移管。「参加者ログ」と「管理操作ログ」を別概念として扱う |
| [#62](https://gitlab.com/11h27m/nexus-mobile/-/work_items/62) QR 発行ウィザード | **残置**（hidden beta） |
| [#63](https://gitlab.com/11h27m/nexus-mobile/-/work_items/63) MapDataset draft 一覧・編集画面 | Nexus Studio へ移管 |
| [#64](https://gitlab.com/11h27m/nexus-mobile/-/work_items/64) validation 結果の表示 | Nexus Studio へ移管 |
| [#65](https://gitlab.com/11h27m/nexus-mobile/-/work_items/65) publish / rollback 操作 | Nexus Studio へ移管 |
| [#66](https://gitlab.com/11h27m/nexus-mobile/-/work_items/66) `/settings` の処遇 | **廃止**（admin-web 排除により自明） |

## 却下した選択肢

- **Nexus Studio を本リポジトリの `apps/` 配下に置く**: 肥大化の解消にならず、参加者向けアプリと管理環境のリリースサイクルも分けられないため却下。
- **`apps/admin-web` を拡張して E7 を完成させる**: Nexus Studio 側で承認済みの UI 方針（左 Sidebar / Workspace / Inspector）を、MUI と shadcn が混在した既存画面へ後付けすることになる。到達可能な画面がすべてモックである現状から作り直すのと変わらないため却下。
- **publish / rollback を本リポジトリに残す**: 公開の原子性が2サービスにまたがり、イベントと地図を整合する組み合わせで公開できなくなるため却下。
- **`apps/admin-web` を段階的に縮小して残す**: 二重の管理画面を保守する期間が長引くため却下。

## 後続Issueが前提にできる事項

- 管理画面の実装先は Nexus Studio リポジトリである。本リポジトリに新しい管理画面を追加しない。
- `apps/public-api` は Nexus Studio が書き込んだ公開データを読み取る。書き込みは行わない（CI の `public-api-readonly-check` を維持する）。
- `apps/admin-api` への新規機能追加は、QR hidden beta と参加者ログの範囲に限る。

## 本Issueのスコープ外

- Nexus Studio 側の技術構成（別リポジトリの決定記録による）
- `apps/admin-web` の削除時期（Nexus Studio が同等機能を提供した後、[#87](https://gitlab.com/11h27m/nexus-mobile/-/work_items/87) と併せて判断）
- DB スキーマの具体的な分離方式
- `apps/admin-api` の各エンドポイント無効化の順序
