# E1-3: DB Spot.Code とナビ SpotDto.Id の統合方針

- 移行元ID: E1-3 / 区分: E1
- 依存: E1-2（`docs/decisions/E1-2-hierarchical-ids.md`）
- 判断日: 2026-09-03
- 判断者: リポジトリオーナー（技術的意思決定者）
- 状態: 採用

## 採用方針

参加者向け機能とシステム間連携で使用するスポットの正式な識別子を、MapDataset の **canonical ID** に統一する。

- DB では `Spot.Code` に canonical ID を保持する。
- ナビゲーションでは `SpotDto.Id` に同じ canonical ID を保持する。
- `RouteDto.FromSpotId` / `RouteDto.ToSpotId`、イベントの `SpotCode`、QR のスポットコード、参加者ログの新規 `SpotCode` も同じ canonical ID を使用する。
- DB の `Spot.Id`（GUID）は行を識別する内部主キーとして維持する。管理 API のリソース指定や `Exhibit.SpotId` の外部キーには引き続き GUID を使用し、公開 URL、QR、MapDataset、ナビ経路の識別子としては使用しない。

したがって、新規データでは次の不変条件を満たす。

```text
Spot.Code == SpotDto.Id == route.fromSpotId / route.toSpotId == canonical ID
```

`Spot` は MapDataset と別の canonical エンティティを新設するものではない。検索、展示、イベント、QRなどの参加者向け情報を付加する read model とし、ナビゲーション可能な MapDataset の対象エンティティを同じ canonical ID で参照する。

建物、正式入口、今後定義される部屋・施設・ランドマークなどを目的地にできるが、canonical ID が未確定の対象をスポットとして公開してはならない。経路計算専用ノードを参加者向け目的地として公開する必要が生じた場合も、ノードIDを表示名から推測せず、基準データ上で対象を明示する。

## ID の規則

canonical ID は E1-1 / E1-2 と今後のエンティティ別規則に従う。

1. ASCII 小文字の lower_snake_case を正規形とする。
2. 比較は大文字小文字を区別した完全一致とする。
3. published MapDataset 内で、エンティティ種別をまたいで一意とする。
4. 表示名、座標、配列順から生成しない。
5. 一度公開した canonical ID は不変とする。
6. ID を変更するときは、新しい canonical ID を発行し、旧IDを alias として残す。

現行の `NavigationController` が使用する `OrdinalIgnoreCase` は移行対象であり、canonical ID の比較規則には採用しない。大文字・小文字違いを暗黙に同一視せず、互換性が必要な旧IDだけを明示的な alias として登録する。

## GUID と canonical ID の責務

| 値 | 責務 | 外部公開での扱い |
|---|---|---|
| `Spot.Id`（GUID） | DB行の内部主キー、管理APIのリソース指定、内部外部キー | canonical ID として使用しない |
| `Spot.Code`（string） | DB上の現行 canonical ID | QR、Public API、イベント、検索で使用 |
| `SpotDto.Id`（string） | ナビ read model 上の canonical ID | MapDataset、経路、iOSで使用 |
| legacy alias（string） | 過去のQR・URL・データを現行スポットへ解決する互換キー | 入力としてのみ受理し、応答では canonical ID を返す |

Public API が GUID の `id` と文字列の `code` を同時に返す期間でも、参加者クライアントは `code` をcanonical IDとして扱う。GUID の `id` をナビゲーション、QR生成、ログのスポット識別子へ転用しない。

## alias 方針

現在は本番利用や配布済みQRがないが、将来のID変更時に外部リンクを維持できるよう、aliasを正式な互換機構として最初から用意する。

### データモデル

後続のDB実装では、`spots` とは別に `spot_id_aliases` を追加する。最低限、次の情報を保持する。

| フィールド | 必須 | 規則 |
|---|---|---|
| `alias_code` | 必須 | 旧ID。canonical ID および他の alias と重複不可 |
| `spot_id` | 必須 | `spots.id` への GUID 外部キー |
| `created_at` | 必須 | alias 登録日時 |
| `reason` | 必須 | 改名、旧モック移行、旧QR互換などの理由 |

- alias は別の alias ではなく、`spot_id` を介して現在のスポットへ直接解決する。alias chain は作らない。
- `alias_code` と現行 `Spot.Code` の名前空間は共通とし、どちらか一方にしか登録できない。
- alias の比較も完全一致とする。大文字・小文字違いを自動生成しない。
- 新しい canonical ID を旧 alias と同じ値で再利用しない。
- 外部参照に使われた可能性がある alias は削除しない。スポット廃止後の応答方法は、削除ではなく廃止状態を含む別のライフサイクル方針で決める。

### 解決順

外部からスポットIDを受け取る `/api/spots/by-code/{code}`、ナビスポット取得、経路検索、QR解決などでは、共通 resolver を使用する。

1. `Spot.Code` を完全一致で検索する。
2. 見つからなければ `spot_id_aliases.alias_code` を完全一致で検索する。
3. alias が見つかった場合は、その `spot_id` が指すスポットの現行 `Spot.Code` へ正規化する。
4. どちらにも存在しない場合は Not Found とする。

応答、経路計算、以後の内部イベント、新規ログには解決後の canonical ID を使用する。alias を受け取った場合でも、応答の `Code` / `Id` に alias をそのまま返さない。

## 公開後の変更規則

- 未公開の draft スポットは、他データから参照されていない場合に限り `Spot.Code` を修正できる。
- 一度公開した `Spot.Code` は通常の更新APIで変更できない。
- 公開済みIDを変更する必要がある場合は、専用の改名処理で旧コードを alias に登録してから新しい canonical ID へ切り替える。
- 改名処理は alias 登録と `Spot.Code` 更新を同一トランザクションで行い、どちらか一方だけが反映される状態を作らない。
- 新規QRは常に現行 canonical ID で生成する。旧IDを含むQRは resolver により継続して解決する。

## 既存データの扱い

現行実装には、canonical ID として採用できない開発用・モック用IDがある。

### DB seed

`apps/admin-api/Data/DbSeeder.cs` には次のコードが存在する。

- `SPOT-001`, `SPOT-002`
- `pc_room`, `ctc`, `vehicle_hangar`, `basic_training_room`, `hangar`

### ナビゲーション seed

`apps/public-api/Data/phase1-navigation.json` には次のIDが存在する。

- `entrance`, `reception`, `room-a`
- `stairs-a-1f`, `stairs-a-2f`
- `library`, `lab-b`

これらを名称だけで既存の canonical ID へ自動変換してはならない。特に `ctc` は E1-1 で建物の旧コードとして却下され、建物 canonical ID は `ctc_main` と確定しているが、DB seed の `ctc` が同じ建物を指すかは名称だけでは断定できない。

基準データ移行時に各旧IDの対象エンティティを確定し、次のいずれかとして明示的な対応表を作る。

- 同じ実体を指す: canonical ID へ移行し、旧IDを alias として保持する。
- 開発用ダミーで実体がない: 本番データから除外し、alias は作成しない。
- 対象を特定できない: published データへ含めず、移行エラーとして扱う。

既存の Phase 1 モックIDを新しいcanonical IDの採番根拠にはしない。

## マイグレーション方針

### 必要な変更

- `Spot.Id` の主キー型と `Spot.Code` の列型は変更しない。
- `spot_id_aliases` を追加する additive なDBスキーママイグレーションを実施する。
- `Spot.Code` と `alias_code` を合わせた名前空間の重複をアプリケーションサービスと移行検証で防ぐ。
- DB spot、MapDataset、ナビ read model の対応を検証する移行表を作成する。
- navigation seed、mobile mock、route endpoint、QR resolver、イベント、ログ入力を同じ共通 resolver／canonical IDへ段階的に切り替える。

### 移行順序

1. 既存のDBコード、ナビID、QR・イベント・ログ参照を棚卸しする。
2. 旧IDごとに canonical ID、対象の `Spot.Id`、alias要否を確定した移行表を作る。
3. `spot_id_aliases` と一意性制約を追加する。
4. 同一トランザクション内で必要なaliasを登録し、`Spot.Code` をcanonical IDへ更新する。
5. ナビデータと経路参照を同じcanonical IDへ置換する。
6. resolver、API応答、QR生成、新規ログがcanonical IDを使用することを検証する。
7. DB spot と published navigation spot の対応漏れ、重複、alias chain がないことをvalidatorで検証する。

本番利用前であっても、aliasのスキーマと解決処理をcanonical ID移行と同時に導入する。後から互換性機構を追加すると、どの旧IDが外部利用されたか判断できなくなるためである。

## 履歴データを変更しない

`visit_logs.spot_code` は監査ログのハッシュ計算に含まれている。既存ログの値を書き換えると監査ハッシュチェーンが不整合になるため、過去ログは更新しない。

- resolver 導入後に受け取った alias はcanonical IDへ解決してから新規ログへ保存する。
- 導入前のログに残る旧IDは、その時点の事実として保持し、表示・集計時にalias表で現行canonical IDへ対応付ける。
- 発行済みQRのスナップショットも履歴として保持し、保存済みIDを一括置換しない。アクセス時にaliasで解決する。

## 採用理由

- DBとナビの文字列IDを同一のcanonical IDにすることで、QR、イベント、地図、経路、ログ間の変換漏れをなくせる。
- GUIDを内部主キーとして残すため、既存の管理API、`Exhibit.SpotId` 外部キー、DB関係を大規模に変更せずに移行できる。
- E1-2の階層ID、全体一意性、公開後不変という規則と整合する。
- `Spot` を別のcanonicalエンティティにしないため、同じ場所にDB用IDとMapDataset用IDを二重発行せずに済む。
- aliasを初期移行から導入することで、将来のQR・共有URL・ブックマークをID変更後も維持できる。
- 過去ログとQRスナップショットを不変に保ち、監査性を損なわずに旧IDを解釈できる。

## 却下した選択肢

- **`Spot.Id` のGUIDをナビIDにする**: E1-2の人間が所属を確認できる階層ID規則と一致せず、MapDatasetのcanonical IDとの変換が常に必要になるため却下。
- **DB `Spot.Code` と `SpotDto.Id` を別体系のまま対応表だけで結ぶ**: 新規データでも二重ID管理が継続し、QR・経路・ログごとに変換漏れが発生するため却下。
- **DB主キーを文字列canonical IDへ置き換える**: `Exhibit.SpotId` など既存のGUID外部キーと管理APIへ大きな移行影響があり、canonical ID統合に必須ではないため却下。
- **旧IDをすべて破棄する**: 現時点で本番利用がなくても、将来の改名時にQR・共有URLの互換性を維持できないため却下。
- **大文字・小文字を無視して暗黙にalias扱いする**: E1-2の完全一致規則に反し、誤記と正式aliasを区別できないため却下。
- **旧IDから名称一致でcanonical IDを推測する**: 同名施設や意味の異なるコードを誤統合する可能性があるため却下。
- **過去ログの旧IDを一括更新する**: 監査ハッシュチェーンを壊し、当時受信した値という履歴も失うため却下。

## 後続Issueが前提にできる事項

- 参加者向けスポット識別子の正は文字列canonical IDであり、DBでは `Spot.Code`、ナビでは `SpotDto.Id` に格納する。
- GUIDの `Spot.Id` は内部主キーのまま維持する。
- 外部入力は共通resolverでcanonical IDまたは明示aliasから解決し、出力と新規保存はcanonical IDに正規化する。
- 公開済みcanonical IDは通常更新で変更せず、改名時はalias登録とコード変更を同一トランザクションで行う。
- 既存データは対応表なしに自動変換せず、実体なしのダミーは本番から除外する。
- 過去ログと発行済みQRスナップショットは書き換えない。
- 実装には主キー置換ではなく、aliasテーブルの追加とデータ移行が必要である。

## 後続実装の受入条件

- published DB spot の `Spot.Code` と対応する `SpotDto.Id`、経路の始点・終点IDが完全一致する。
- canonical ID を入力すると対象スポットを取得でき、応答にはcanonical IDが返る。
- 登録済みaliasを入力すると同じ対象へ解決され、応答と新規ログには現行canonical IDが返る／保存される。
- 未登録IDと、登録されていない大文字・小文字違いは Not Found になる。
- `Spot.Code` 同士、alias同士、`Spot.Code` とalias間の重複登録が拒否される。
- aliasからaliasへの参照とalias chainを作成できない。
- 公開済み `Spot.Code` の通常更新が拒否され、専用改名処理ではalias登録とcanonical ID変更が同一トランザクションで完了する。
- 新規QRにはcanonical IDが格納され、旧aliasを含むQRも同じ対象へ解決できる。
- 既存監査ログを変更せず、移行前後で監査ハッシュチェーンの検証結果が変わらない。
- validatorがDB spotとpublished navigation spotの対応漏れ、ID不一致、重複、参照先不在を検出する。

## 本Issueのスコープ外

- 既存seed各件の実地データとの照合とcanonical IDの具体値確定
- `spot_id_aliases` のEF Coreモデル・マイグレーション・resolver実装
- Public API / OpenAPI / iOSクライアントの契約変更
- navigation seed、mobile mock、MapDataset基準データの実データ置換
- 管理画面の改名操作UIと廃止スポットのライフサイクル

これらは後続実装で扱うが、識別子の責務、aliasの制約、解決順、移行要否について追加の方針判断は不要とする。
