# E6-1: iOS のタブ構成を確定する

- 移行元ID: E6-1 / 区分: E6 / 根拠: [Work item #46](https://gitlab.com/11h27m/nexus-mobile/-/work_items/46)「SwiftUIアプリ基盤と4タブ構成の実装」、`apps/nexus-ios/Nexus/Application/AppTab.swift`、2026-09-22 のリポジトリオーナーの判断
- 判断日: 2026-09-22
- 判断者: リポジトリオーナー（技術的意思決定者）
- 状態: 採用
- 依存: [E0-6](E0-6-ios-client-of-record.md)（iOS クライアントの正本）

## 採用方針

**参加者向け iOS アプリのタブ構成を次の4タブとする。**

| 順 | タブ | 識別子 | 利用者の目的 |
|---|---|---|---|
| 1 | **ホーム** | `home` | 参加を始める、興味を見つける |
| 2 | **マップ** | `map` | 場所と経路を確かめる |
| 3 | **案内** | `guide` | 疑問を解消し、学校を知る |
| 4 | **探す** | `search` | 名前や興味から候補を選ぶ |

`docs/v1.0-scope.md` の E6 が従来定めていた **Home / Map / Info（3タブ）から変更**する。

## 判断の背景

E6-1 判断以前、タブ構成は4つの記述に分かれており、**実装はリポジトリ外の資料に一致していた**。

| 出典 | 定義 | 更新日 |
|---|---|---|
| `docs/v1.0-scope.md` E6 ／ Work item #45 | Home / Map / Info（3タブ） | 2026-08-31 |
| `docs/ios-native-migration-plan.md` | Home / Map / 時間割 / 情報（4タブ） | 2026-09-11 |
| 設計ノート（リポジトリ外） | ホーム / マップ / 案内 / 探す（4タブ） | 2026-09-10 |
| **実装** `apps/nexus-ios/Nexus/Application/AppTab.swift:3-8` | `home` / `map` / `guide`（案内）/ `search`（探す） | — |

Work item としては [#46](https://gitlab.com/11h27m/nexus-mobile/-/work_items/46)「SwiftUIアプリ基盤と**4タブ構成**の実装」として 2026-09-07 に発行済みであり、個別タブも [#86](https://gitlab.com/11h27m/nexus-mobile/-/work_items/86)（案内画面）・[#27](https://gitlab.com/11h27m/nexus-mobile/-/work_items/27)（探す画面）・[#85](https://gitlab.com/11h27m/nexus-mobile/-/work_items/85)（Map画面）として立っていた。

**決定と実装は一致していたが、`docs/v1.0-scope.md` に反映されていなかった。** 本記録はその反映である。

## 各タブの責務

| タブ | 責任を持つこと | 他タブへ渡すこと |
|---|---|---|
| ホーム | 要約、入口、体験・カテゴリ、重要案内 | 検索要求、イベント／地点、案内記事 |
| マップ | 構内図、地点詳細、出発地、経路、階 | 選択地点、経路確認要求 |
| 案内 | 受付、アクセス、困ったとき、FAQ、学校紹介 | 関連地点、経路確認要求 |
| 探す | 検索入力、カテゴリ、結果、条件保持 | 選択した地点／イベント |

## 「Info」との対応

従来の `Info` タブが担う想定だった内容（学校生活・寮生活・学科紹介・交通アクセス）は、**「案内」タブが引き継ぐ**。Work item [#49](https://gitlab.com/11h27m/nexus-mobile/-/work_items/49)（Info コンテンツの供給元）、[#51](https://gitlab.com/11h27m/nexus-mobile/-/work_items/51)〜[#54](https://gitlab.com/11h27m/nexus-mobile/-/work_items/54)（学科紹介・寮生活・学校生活・アクセス）は、いずれも「案内」タブ配下として読み替える。

「探す」タブは従来の3タブ構成には存在しなかった。Home の検索導線（[#47](https://gitlab.com/11h27m/nexus-mobile/-/work_items/47)）と施設検索（[#27](https://gitlab.com/11h27m/nexus-mobile/-/work_items/27)）を独立したタブとして扱う。

## 理由

- 実装（`AppTab.swift`）と Work item #46 の双方が4タブで一致している。
- 「探す」を独立させることで、ホームからの検索導線とマップ上の地点選択を同じ検索結果へ集約できる。
- 「案内」は場所ではなく疑問から入る導線であり、マップ（場所から入る）と目的が異なるため分離する価値がある。

## 却下した選択肢

- **Home / Map / Info の3タブを維持する**: 実装・Work item のいずれとも一致せず、「探す」の置き場所がない。却下。
- **Home / Map / 時間割 / 情報の4タブ**（`docs/ios-native-migration-plan.md` の記述）: 「時間割」に相当する機能は実装されておらず、v1.0 の必須成果にも含まれない。却下。
- **タブを5つ以上にする**: 1画面1主目的の原則（`docs/design-rules.md`）と、下部ナビの可読性を損なうため却下。

## 後続Issueが前提にできる事項

- タブの識別子は `home` / `map` / `guide` / `search` であり、`AppTab` の rawValue と一致する。
- Info 系コンテンツの受け皿は「案内」タブである。
- タブ間の遷移要求は `AppRouteRequest`（`apps/nexus-ios/Nexus/Application/AppRouteRequest.swift`）を経由し、View が遷移先タブを直接決めない。

## 本Issueのスコープ外

- 各タブ内の画面構成・情報設計
- タブアイコンの最終アセット
- Work item #45 の整理（旧タイトル「タブ構成を Home / Map / Info に再定義する」が残っている場合の更新）
