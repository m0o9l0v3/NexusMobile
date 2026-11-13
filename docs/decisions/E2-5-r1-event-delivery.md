# E2-5 改訂1: イベント・開催回・カテゴリを参加者 bundle に同梱する

- 対象: [E2-5 参加者向け公開データ配信契約 v2](E2-5-participant-data-delivery-v2.md)（§10「将来の拡張」の1項目目を本改訂で扱う）
- 関係: [#48](https://github.com/m0o9l0v3/NexusMobile/issues/48)（Home の状態表示）、[#22](https://github.com/m0o9l0v3/NexusMobile/issues/22)（iOS の取得・保存）、[#83](https://github.com/m0o9l0v3/NexusMobile/issues/83) P07（おすすめの選定）、[E6-6](E6-6-guidance-content-source.md)（開催回に依存する情報は Studio 側）、NexusStudio 決定事項28 v02 S4-3・S4-4、決定事項07 v03
- 判断日: 2026-11-13（§1 の3点は利用者決定）
- 判断者: リポジトリオーナー（技術的意思決定者）
- 状態: **起案**。本書の PR のマージで採用とする。payload 契約は 2.0.0 → **2.1.0**（マイナー版）になる

## 0. いまの状態

- Studio はイベント・開催回（開催日を含む）・カテゴリを公開できる（S4-4）。
- しかし参加者 bundle（E2-5）に射影されるのは**地点と地図だけ**で、Studio で公開したイベントは iOS に届かない（`ParticipantBundleProjection`）。
- public-api の `GET /api/events/today` は旧 admin-api の DB を読むもので、Studio の公開とつながっていない。iOS も使っていない。
- iOS の Home は loading / empty / error / 保存版の画面とテストを持つが、取得先（`HomeClient`）は未接続である。

## 1. 決定

| ID | 論点 | 決定 |
|---|---|---|
| EV-D1 | イベントの届け方 | **E2-5 の bundle に同梱する。** イベント・開催回・カテゴリを、地点・地図と同じ1つの版として配信する |
| EV-D2 | Home の「お知らせ」 | **v1.0 では出さない。** 当日の変更は、イベントの訂正・枠の中止・取り下げで伝える |
| EV-D3 | Home の「おすすめのイベント」（#83 P07） | **人が選ばず、これから始まる順に自動で並べる。** 見出しも「おすすめ」ではなく「この後のイベント」のように、並べ方が分かる言葉にする |

### EV-D1 の理由

- 会場の地点 ID が**同じ版の `spots[]` で必ず解決できる**。別の配信にすると、イベントと地点の版がずれたときの参照切れを iOS で扱う必要が出る（E2-5 §10 が挙げていた利点）。
- iOS の取得・検証・保存・原子的な切替（E2-5 §6、#22）と、通信断時の保存版の表示をそのまま使える。保存の仕組みを2つ持たない。
- 終日の枠の時刻を、射影のときに同じ Release の開催時間から解決できる（S4-3）。
- 公開の経路が Studio だけになる。旧 API（`/api/events/today`）を使い続けると、公開の経路が2つになる。

## 2. Payload 契約 2.1.0 の追加分

2.0.0 の項目は変えない。トップレベルに次の3つを**任意項目**として加える。2.0.0 の読み手は未知の項目を無視する（E2-5 §6 規則6）ので、後方互換を保つ。

```json
{
  "nexus_bundle": { "schema_version": "2.1.0", "bundle_version": 43, "release_id": "…", "published_at": "…" },
  "spots": [],
  "id_aliases": [],
  "map": null,
  "categories": [
    { "id": "…uuid…", "name": "体験授業" }
  ],
  "occurrences": [
    {
      "id": "…uuid…",
      "name": "8月オープンキャンパス",
      "days": [
        { "id": "…uuid…", "date": "2027-08-01", "public_start": "10:00", "public_end": "15:00", "status": "normal", "cancel_note": null }
      ]
    }
  ],
  "events": [
    {
      "id": "…uuid…",
      "title": "模擬授業",
      "description": null,
      "category_id": "…uuid…",
      "occurrence_id": "…uuid…",
      "slots": [
        {
          "id": "…uuid…",
          "day_id": "…uuid…",
          "date": "2027-08-01",
          "time_mode": "fixed",
          "start": "10:30",
          "end": "11:15",
          "participation": "atStart",
          "status": "normal",
          "cancel_note": null,
          "venues": [ { "spot_id": "mb_2f_rm_001", "note": "受付は入口" } ]
        }
      ]
    }
  ]
}
```

（値は形式を示す例で、実データではない。項目名・値の綴りの正本は [`participant-bundle-v2.schema.json`](../schemas/participant-bundle-v2.schema.json) とする。値の綴りは Studio の値をそのまま写す（`normal` / `cancelled`、`fixed` / `allDay`、`atStart` / `anytime`。2.0.0 の `utilization` の `noNewSelection` と同じ扱い）。）

- **配列の順序が表示順**である（カテゴリ、開催日、枠、会場）。Studio の順序をそのまま写す。
- **時刻**はキャンパス現地時刻（JST）の `HH:mm`、日付は `YYYY-MM-DD`。タイムゾーンは書かず、JST と定める。
- **終日の枠**（`time_mode: allDay`）は、射影のときに開催日の `public_start` / `public_end` を `start` / `end` に入れる（S4-3）。iOS は時刻を自分で解決しない。表示では `time_mode` で終日と分かるようにする（EV-43）。
- **中止**は枠の `status` と開催日の `status` の両方を持つ。開催日が中止なら、その日の枠はすべて中止として扱う（EV-09）。中止の枠も配列から除かず、`cancel_note` とともに届ける。
- **取り下げたイベント**は含めない（E2-5 §5.3 の4と同じ扱い）。
- `categories` には参加者向けの `id` と `name` だけを入れる。Studio 内部の「新規イベントで選べるか」（`Selectable`）は入れない。

### 2.1 不変条件（E2-5 §5.3 に加える）

7. `events[].slots[].venues[].spot_id` は、同じ bundle の `spots[].id` に存在する。比較は大文字小文字を区別する。
8. `events[].category_id`（null でない場合）は `categories[].id` に、`events[].occurrence_id` は `occurrences[].id` に、`slots[].day_id` はその開催回の `days[].id` に存在する。`slots[].date` はその開催日の `date` と一致する。
9. `events[].id`・`slots[].id`・`occurrences[].id`・`days[].id`・`categories[].id` は、それぞれ bundle 内で一意。
10. `time_mode: allDay` の枠の `start` / `end` は、その開催日の `public_start` / `public_end` と一致する。

不変条件を満たさない場合は、E2-5 §3.3 の3のとおり**公開そのものを失敗させる**。このため、公開中のイベントが会場として使っている地点を取り下げる公開は、イベントの会場を直すまで失敗する（§4 EV-O2）。

### 2.2 射影の規則の変更（E2-5 §3.3 の2）

新しい版を作るきっかけに、**イベント・開催回・カテゴリの公開と取り下げ**を加える。内容は、その時点で公開中のものから全量で組み立てる（差分は作らない）。イベント1件の訂正でも bundle 全体が新しい版になるが、E2-5 §3.4 の大きさの上限・警告の範囲に十分収まる見込みである（イベントは数十件規模）。

## 3. Home での使い方（#48）

- **これから参加できる枠**：開始時刻に参加する枠（`atStart`）は開始前、随時参加の枠（`anytime`）は終了前のもの。終日の枠は随時参加なので、開催中も終了まで残る。（起案時は「現在時刻以降に始まる枠」としていたが、開催中に参加できる終日・随時参加の枠が開始と同時に消えるため、#48 の実装で改めた。）
- **次のイベント**：これから参加できる枠のうち、中止でない最も早い枠。
- **この後のイベント**：これから参加できる枠を開始の早い順に並べる（EV-D3）。中止の枠も中止と分かる形で残す（EV-O1）。最大10件。見出しは「この後のイベント」。
- **お知らせ**：表示しない（EV-D2）。#48 で Home のお知らせ欄と `HomeSnapshot` の項目を外した。
- **通信断**：保存済みの bundle からイベントを出し、保存版であることを表示する（既存の `saved` 状態）。保存版で今後の枠が0件のときも保存版の表示を出し、「すべて終了」と断定しない。
- **読み直し**：時刻と版で中身が変わるため、Home の再表示（タブを戻す・詳細から戻る）、前面復帰、bundle の更新確認の完了のたびに読み直して射影し直す。表示中の内容は読み込み中に戻さず、読み直しに失敗しても残す。表示したまま時間が経つ間の自動更新はしない。

## 4. 未決事項（いずれも決定済み）

| ID | 論点 | 結論 |
|---|---|---|
| EV-O1 | 中止の枠を「この後のイベント」に中止と分かる形で残すか、除くか | **決定（2026-11-13 利用者判断）：残す。** 一覧には「中止」と中止案内を文字で示し、経路の操作は出さない。次のイベントには選ばない |
| EV-O2 | 公開中のイベントが使う地点を取り下げるとき、公開を失敗させるだけでよいか。どのイベントが使っているかを示す必要があるか | **決定（NexusStudio#37 のマージ、2026-11-13）：既存の動作で足りる。** 取り下げは `spot_in_use` が公開阻止とし、使っているイベント名を所見に出す。取り下げ済み（`withdrawn`）のまま公開する経路は `spot_withdrawn_in_use` で止める |
| EV-O3 | Figma の Home から「お知らせ」を外し、見出しを改める | **決定（2026-11-13 利用者判断）：iOS を先に直す。** Figma への反映は #48 の PR に差分として記録し、Figma 担当に渡す |

## 5. 担当

| 作業 | 担当 |
|---|---|
| 射影の拡張、不変条件の検査、公開前検証への追加 | NexusStudio（別 Issue を立てる） |
| `participant-bundle-v2.schema.json` を 2.1.0 に更新 | NexusMobile（Studio の実装と同じ変更単位で揃える） |
| iOS のデコード・不変条件の検査・Home への接続 | NexusMobile #22・#48 |
| public-api | 変更なし（payload をそのまま返す） |
| `/api/events/today` | 本改訂では変えない（E2-5 §4.4 のまま）。iOS は使わない。撤去は旧 admin-api の扱いとあわせて別に決める |

## 6. 版番号について

E1-4 の GeoJSON 契約（`nexus.schema_version`）の 2.1.0 は欠番にした（[E1-4 改訂3](E1-4-r3-apple-map-alignment.md) §6）。本改訂の 2.1.0 は**別の契約**（参加者 bundle の `nexus_bundle.schema_version`）の版であり、GeoJSON の欠番とは関係しない。

## 7. 選ばなかった案

| 案 | 選ばなかった理由 |
|---|---|
| イベント専用の配信表とエンドポイントを Studio から作る | 地点と版が分かれ、会場の参照切れへの対応と、iOS 側の保存・切替が2系統になる |
| 旧 `/api/events/today`（admin-api の DB）を使う | Studio で公開した内容が届かず、公開の経路が2つになる。当日分しか返さず、保存版の規則もない |
| お知らせを Studio に加える | 当日の会場変更などを知らせられるが、Studio に新しい公開対象と画面が要る。v1.0 ではイベントの訂正・中止で代える |
| おすすめを Studio で人が選ぶ | 選んだ人と理由を残せるが、項目と画面の追加が要り、選ぶ作業も毎回発生する |
