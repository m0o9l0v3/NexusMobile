# Nexus v1.0 案内記事・建物説明文のレビュー用ドラフト

**オーナー確認済み（2026-11-25）。** Part 1 の案内10記事を `GuidanceArticles.json` に同梱しました。Part 2 の建物14棟は10棟の説明文を採用し、4棟（`ab`、`aptr`、`hgr_a`、`hgr_b`）は `null` のままとすることで確定しました。建物説明文はNexusStudioへの投入待ちです。

来場者が電波の届きにくい場所でも、次に何をすればよいか、学校で何を学べるかを1〜2分でつかめる分量にまとめました。学校情報の出典は日本航空大学校公式サイトに限り、本文・地図の関連地点・公式連絡先で構成しています。開催回によって変わる案内はホーム画面・申込時の案内・現地のスタッフや表示に委ねます。

### オーナーレビュー時の確認項目

- 学科名・年限・コース名と、在学中／就職後に目指す資格の区別。
- 地図の正式名「男子寮（リンドバーグホール）」と、一部女子エリアを設けた現在の運用の併記。
- 体調不良時の行動と緊急時の119番通報、見学の問い合わせと学校代表の電話の使い分け、受付・駐車・施設利用を開催回ごとに確認する方法。
- 目次と記事の短い表題での「施設利用・学食」「学生寮」の表記統一。
- U-2の建物説明文と、公式サイトで確認できた各棟の用途との対応。 [E6-6](../decisions/E6-6-guidance-content-source.md)

## Part 1　案内タブの10記事

記事ごとに `id` 以下の値を示します。本文の小見出しが `heading`、直下の各段落が `paragraphs` の1要素です。FAQは質問ごとに回答段落をまとめます。表にした連絡先と関連地点は1行が配列の1要素です。省略した任意項目は転記不要です。「編集メモ」はレビュー専用です。連絡先は現行の読み込み実装が受け付ける `officialContacts` に合わせています。 [原稿形式](issue-86-guidance-articles-format.md)・[読み込み実装](../../apps/nexus-ios/Nexus/Features/Guidance/Data/BundledGuidanceCatalog.swift)・[目次](../../apps/nexus-ios/Nexus/Features/Guidance/Models/GuidanceMenu.swift)

### 困ったとき・緊急

#### 気分が悪くなったら（`health`）

- `id`　`health`
- `kind`　`helpHealth`
- `navigationTitle`　気分が悪くなったら
- `title`　体調が悪いときは、その場で助けを呼んでください
- `subtitle`　自分や同行者に具合の悪さやけががあるときに。
- `source`　日本航空大学校公式サイト（https://www.jaa-tech.jp/faq/）2026-11-25確認。体調不良時の行動・119番通報は一般案内。
- `confirmation`　`confirmedOn: "2026-11-25"` ／ `confirmer: "リポジトリオーナー（公式HP照合）"`

**冒頭の案内 `highlight`**

- `tone`　caution
- `systemImageName`　cross.case
- `title`　無理に歩かず、近くの人へ
- `body`　見学を中断し、近くのスタッフや同行者に声をかけてください。呼びかけに反応がない、普段どおりの呼吸がないなど、緊急のときはすぐに119番へ通報してください。

**本文 `sections`**

**場所と様子を伝える**（`id: tell`）

建物名や近くの看板を目印に、どこで、誰が、どんな状態かを伝えてください。同行者の具合が悪いときは、そばにいる人を指名してスタッフを呼んでもらいましょう。

**休める場所を知りたいとき**（`id: support`）

近くのスタッフに、今いる場所から案内してもらいましょう。相談先を事前に知りたいときは、ホーム画面で参加する開催日のイベント案内や、申込時の案内を確認してください。

**地図**　`relatedSpots: []`

**公式連絡先 `officialContacts`**

| `id` | `kind` | `label` | `url` |
|---|---|---|---|
| `faq` | `web` | よくあるご質問 | <https://www.jaa-tech.jp/faq/> |

**編集メモ**

- 参照元　[よくあるご質問](https://www.jaa-tech.jp/faq/)・[オープンキャンパス](https://www.jaa-tech.jp/opencampus/)
- 意図的に削った項目　在学生向けの保健室数・受診支援、来場者向けに確認できない救護室の場所。
- 要確認ポイント　緊急時の最初の行動が伝わるか。学校の電話を救急窓口として表示しない構成でよいか。

#### 困ったとき（`help`）

- `id`　`help`
- `kind`　`help`
- `homeShortcut`　`help`
- `navigationTitle`　困ったとき
- `title`　道に迷ったとき・集合場所が分からないとき
- `subtitle`　目印を一つ見つけると、スタッフに現在地を伝えやすくなります。
- `source`　日本航空大学校公式サイト（https://www.jaa-tech.jp/opencampus/）2026-11-25確認。道に迷ったとき・はぐれたときの行動は一般案内。
- `confirmation`　`confirmedOn: "2026-11-25"` ／ `confirmer: "リポジトリオーナー（公式HP照合）"`

**冒頭の案内 `highlight`**

- `tone`　informational
- `systemImageName`　info.circle
- `title`　いったん安全な場所に立ち止まる
- `body`　近くに見える建物名や案内板の文字を確かめ、スタッフに「今いる場所」と「行きたい場所」を伝えてください。

**本文 `sections`**

**行き先を確かめる**（`id: meeting`）

ホーム画面で参加する開催日のイベント案内を開くか、申込時の案内を見直してください。現地では案内表示を見て、分かれ道や集合場所に迷ったら近くのスタッフに尋ねてください。

**同行者とはぐれたとき**（`id: separated`）

連絡が取れるときは、今いる場所の目印を共有してください。連絡がつかないときや、落とし物をしたときも、近くのスタッフに相談できます。

**地図**　`relatedSpots: []`

**公式連絡先 `officialContacts`**

| `id` | `kind` | `label` | `url` |
|---|---|---|---|
| `visitPhone` | `phone` | オープンキャンパス・学校見学のお問い合わせ（0120-87-8622） | `tel:0120-87-8622` |
| `schoolPhone` | `phone` | 学校代表・その他のお問い合わせ（0123-28-1155） | `tel:0123-28-1155` |
| `contacts` | `web` | お問い合わせ一覧 | <https://www.jaa-tech.jp/contact-information/> |

**編集メモ**

- 参照元　[オープンキャンパス](https://www.jaa-tech.jp/opencampus/)・[お問い合わせ一覧](https://www.jaa-tech.jp/contact-information/)
- 意図的に削った項目　常設の案内所とみなせる地点、遺失物窓口の建物名・部屋番号。
- 要確認ポイント　二つの電話窓口の用途と、現地ではスタッフに相談する順序が明確か。

### 当日のご案内

#### 受付のご案内（`reception`）

- `id`　`reception`
- `kind`　`standard`
- `homeShortcut`　`reception`
- `navigationTitle`　受付のご案内
- `title`　到着したら、参加する回の受付へ
- `subtitle`　来校前の確認と、現地で迷ったときの尋ね方。
- `source`　日本航空大学校公式サイト（https://www.jaa-tech.jp/opencampus/）2026-11-25確認
- `confirmation`　`confirmedOn: "2026-11-25"` ／ `confirmer: "リポジトリオーナー（公式HP照合）"`

**本文 `sections`**

**出発前に確認すること**（`id: before`）

ホーム画面で参加する開催日のイベント案内を開き、申込時の案内とあわせて集合先を確認してください。電波が届きにくい場所でも見返せるよう、集合先を控えておくと安心です。

**会場に着いたら**（`id: arrival`）

現地の案内表示に沿って受付へ向かってください。場所が分からないときは、参加するイベント名を近くのスタッフに伝えてください。出発前のお問い合わせはオープンキャンパス・学校見学の窓口へどうぞ。

**地図**　`relatedSpots: []`

**公式連絡先 `officialContacts`**

| `id` | `kind` | `label` | `url` |
|---|---|---|---|
| `visitPhone` | `phone` | オープンキャンパス・学校見学のお問い合わせ（0120-87-8622） | `tel:0120-87-8622` |
| `openCampus` | `web` | オープンキャンパス | <https://www.jaa-tech.jp/opencampus/> |

**編集メモ**

- 参照元　[オープンキャンパス](https://www.jaa-tech.jp/opencampus/)・[お問い合わせ一覧](https://www.jaa-tech.jp/contact-information/)
- 意図的に削った項目　受付の建物・階・時刻、体験の順序や持ち物の一律指定。
- 要確認ポイント　ホーム画面、申込時の案内、現地表示から受付を探せる書き方か。

#### 交通アクセス（`access`）

- `id`　`access`
- `kind`　`access`
- `homeShortcut`　`access`
- `navigationTitle`　交通アクセス
- `title`　新千歳空港キャンパスへの行き方
- `subtitle`　JR千歳駅からの送迎と、空港・高速道路からのアクセス。
- `source`　日本航空大学校公式サイト（https://www.jaa-tech.jp/campus-life/access/）2026-11-25確認
- `confirmation`　`confirmedOn: "2026-11-25"` ／ `confirmer: "リポジトリオーナー（公式HP照合）"`

**交通手段別の本文 `accessSegments`**

**電車**（`mode: train` ／ `relatedSpots: []`）

- `sections[0].id`　`rail`
- `heading`　鉄道はJR千歳駅へ
- `paragraphs[0]`　札幌方面からは快速エアポートなどでJR千歳駅へ向かいます。駅から学校までは車で約20分です。送迎を希望する方は「バス」の案内も確認してください。

**バス**（`mode: bus` ／ `relatedSpots: []`）

- `sections[0].id`　`shuttle`
- `heading`　JR千歳駅から送迎バスを利用する
- `paragraphs[0]`　学校はJR千歳駅からキャンパスまでの送迎バスを案内しています。利用を希望する方は、オープンキャンパス参加申込時にバスも申し込み、乗り場と運行予定をその回の案内で確認してください。

**自動車**（`mode: car` ／ `relatedSpots: []`）

- `sections[0].id`　`drive`
- `heading`　高速道路・空港から車で向かう
- `paragraphs[0]`　道央自動車道の新千歳空港インターチェンジから約3分、新千歳空港から約10分が目安です。駐車場を利用できるか、どこから入るかは、ホーム画面の開催日別のイベント案内や申込時の案内で確認してください。到着後は現地の表示やスタッフの誘導に従ってください。

**全交通手段に共通の下部本文 `sections`**

**キャンパスの所在地**（`id: address`）

日本航空大学校 北海道 新千歳空港キャンパス　〒066-8622 北海道千歳市泉沢1007-95

**飛行機で来る方へ**（`id: air`）

各地から新千歳空港へ向かい、到着後は陸路でキャンパスに移動します。空港ターミナルとキャンパスは別の場所です。参加する回の集合先を確かめてから出発してください。

**地図**　`relatedSpots: []`

**公式連絡先 `officialContacts`**

| `id` | `kind` | `label` | `url` |
|---|---|---|---|
| `access` | `web` | アクセス | <https://www.jaa-tech.jp/campus-life/access/> |
| `visitPhone` | `phone` | オープンキャンパス・学校見学のお問い合わせ（0120-87-8622） | `tel:0120-87-8622` |

**編集メモ**

- 参照元　[アクセス](https://www.jaa-tech.jp/campus-life/access/)・[オープンキャンパス](https://www.jaa-tech.jp/opencampus/)・[お問い合わせ一覧](https://www.jaa-tech.jp/contact-information/)
- 意図的に削った項目　航空便数・乗入れ会社・運行時刻、駐車の可否・料金・位置。
- 要確認ポイント　駅名とバスの申込方法、車の所要時間が目安であること、駐車を事前確認する案内をご確認ください。

#### 施設利用・学食（`facility`）

- `id`　`facility`
- `kind`　`standard`
- `navigationTitle`　施設利用・学食
- `title`　学食・売店・体育館を知る
- `subtitle`　学生が食事や買い物、運動に使う施設を紹介します。
- `source`　日本航空大学校公式サイト（https://www.jaa-tech.jp/campus-life/dormandcafeteria/）2026-11-25確認
- `confirmation`　`confirmedOn: "2026-11-25"` ／ `confirmer: "リポジトリオーナー（公式HP照合）"`

**本文 `sections`**

**学生食堂 RAINBOW**（`id: dining`）

寮生は朝・昼・夕の食事に、通学生は昼食に利用します。管理栄養士が献立を考え、北海道の旬の食材も取り入れています。食物アレルギーがある方は、来場前に学校へ相談し、当日も食べる前に表示や対応内容を確かめてください。

**売店 GENERAL STORE**（`id: store`）

食堂に併設された売店では、食品や日用品のほか、学校のオリジナルグッズも扱っています。

**体育館とトレーニングジム**（`id: gym`）

アリーナにはバスケットボールやバレーボールのコートがあり、2階にはトレーニングジムがあります。見学できる範囲や休憩に使える場所は、当日の案内表示やスタッフに確認してください。

**地図 `relatedSpots`**

| `canonicalSpotId` | `displayName` |
|---|---|
| `dh` | 食堂 |
| `ar` | アリーナ |

**公式連絡先 `officialContacts`**

| `id` | `kind` | `label` | `url` |
|---|---|---|---|
| `dormFacilities` | `web` | 学生寮・食堂・売店・体育館 | <https://www.jaa-tech.jp/campus-life/dormandcafeteria/> |

**編集メモ**

- 参照元　[学生寮・食堂・売店・体育館](https://www.jaa-tech.jp/campus-life/dormandcafeteria/)・[施設・設備・機材](https://www.jaa-tech.jp/campus-life/facilities/)・[オープンキャンパス](https://www.jaa-tech.jp/opencampus/)
- 意図的に削った項目　当日の昼食提供・休憩場所の確約、営業時間、メニュー、座席数。
- 要確認ポイント　在学生の普段の利用と来場者が当日利用できる範囲を読み分けられるか。

#### 注意事項・マナー（`manners`）

- `id`　`manners`
- `kind`　`standard`
- `navigationTitle`　注意事項・マナー
- `title`　見学に適した服装と靴
- `subtitle`　屋外を歩いたり、実習設備のそばで体験したりすることがあります。
- `source`　日本航空大学校公式サイト（https://www.jaa-tech.jp/opencampus/）2026-11-25確認。見学中の行動は一般案内。
- `confirmation`　`confirmedOn: "2026-11-25"` ／ `confirmer: "リポジトリオーナー（公式HP照合）"`

**本文 `sections`**

**服装は自由です**（`id: clothes`）

屋外での見学や体験に備え、動きやすい服装と履き慣れた靴でお越しください。学校はスカート、ヒール、履き慣れていない靴での参加を控えるよう案内しています。

**実習設備を見学するとき**（`id: tour`）

案内された通路を歩き、機材に触れたいときは先にスタッフに尋ねてください。体験中に説明が聞き取れなかったときは、その場で確認しましょう。

**地図**　`relatedSpots: []`

**公式連絡先 `officialContacts`**

| `id` | `kind` | `label` | `url` |
|---|---|---|---|
| `openCampus` | `web` | オープンキャンパス | <https://www.jaa-tech.jp/opencampus/> |

**編集メモ**

- 参照元　[オープンキャンパス](https://www.jaa-tech.jp/opencampus/)
- 意図的に削った項目　開催回ごとの装備指定、学校が一律に定めたと確認できない持込制限。
- 要確認ポイント　公式の「お控えください」という強さを保ち、服装の自由も伝わるか。

### 学校を知る

#### 学科紹介（`department`）

- `id`　`department`
- `kind`　`standard`
- `navigationTitle`　学科紹介
- `title`　航空に関わる仕事から見る4学科
- `subtitle`　設計、整備、地上支援、旅客サービス。それぞれの学びと進路を紹介します。
- `source`　日本航空大学校公式サイト（https://www.jaa-tech.jp/course/）2026-11-25確認
- `confirmation`　`confirmedOn: "2026-11-25"` ／ `confirmer: "リポジトリオーナー（公式HP照合）"`

**本文 `sections`**

**トータルモビリティ工学科（4年制）**（`id: engineering`）

3次元CADで部品を設計し、プログラミングで機械を動かす技術を学びます。CAD利用技術者試験などに挑戦でき、卒業時には「高度専門士」の称号が得られます。航空・宇宙のほか、自動車やITの設計・開発職にもつながります。

**航空整備科（3年制）**（`id: maintenance`）

1年次は機体やエンジンの基礎を学び、2年次から「一等航空整備士養成コース」「二等航空整備士コース」「二等航空運航整備士コース」「製造技術コース」に分かれます。整備系では航空整備の国家資格を目指し、一等航空整備士の資格取得は就職後が目標です。製造技術コースでは航空機や宇宙関連機器を造る技術者を目指します。

**グランドハンドリング科（2年制）**（`id: ground`）

航空機の誘導、貨物の積み降ろし、空港で働く特殊車両の操作を学びます。新千歳空港での実習を経験し、大型特殊自動車運転免許や航空特殊無線技士など、地上から運航を支える仕事に役立つ資格を目指します。

**キャビンアテンダント・グランドスタッフ科（2年制・3年制）**（`id: cabin`）

「エアラインコース」は2年制、長期留学を組み込んだ「エアライン・留学コース」は3年制です。どちらも客室を再現した設備での保安・接客や、空港での搭乗手続きを学び、客室乗務員とグランドスタッフの両方を目指せます。

**地図 `relatedSpots`**

| `canonicalSpotId` | `displayName` |
|---|---|
| `ctc_main` | CTC |

**公式連絡先 `officialContacts`**

| `id` | `kind` | `label` | `url` |
|---|---|---|---|
| `courses` | `web` | 学科紹介 | <https://www.jaa-tech.jp/course/> |
| `engineering` | `web` | トータルモビリティ工学科 | <https://www.jaa-tech.jp/course/engineering/> |
| `maintenance` | `web` | 航空整備科 | <https://www.jaa-tech.jp/course/maintenance/> |
| `groundHandling` | `web` | グランドハンドリング科 | <https://www.jaa-tech.jp/course/technology/> |
| `cabin` | `web` | キャビンアテンダント・グランドスタッフ科 | <https://www.jaa-tech.jp/course/ca/> |

**編集メモ**

- 参照元　[学科紹介](https://www.jaa-tech.jp/course/)・[トータルモビリティ工学科](https://www.jaa-tech.jp/course/engineering/)・[航空整備科](https://www.jaa-tech.jp/course/maintenance/)・[グランドハンドリング科](https://www.jaa-tech.jp/course/technology/)・[キャビンアテンダント・グランドスタッフ科](https://www.jaa-tech.jp/course/ca/)・[施設・設備・機材](https://www.jaa-tech.jp/campus-life/facilities/)
- 意図的に削った項目　就職・内定・合格の実績値、企業別の採用人数、教員名・出向元。
- 要確認ポイント　4学科の正式名称、各コースと修業年限、一等航空整備士を目指す時期。

#### 学校生活（`schoolLife`）

- `id`　`schoolLife`
- `kind`　`standard`
- `navigationTitle`　学校生活
- `title`　サークルと行事で広がる学生生活
- `subtitle`　授業以外にも、ほかの学科の学生と知り合える場があります。
- `source`　日本航空大学校公式サイト（https://www.jaa-tech.jp/campus-life/schoollife/）2026-11-25確認
- `confirmation`　`confirmedOn: "2026-11-25"` ／ `confirmer: "リポジトリオーナー（公式HP照合）"`

**本文 `sections`**

**好きなことを一緒に楽しむ**（`id: clubs`）

体育館でのバスケットボールやバレーボールのほか、音楽、太鼓、ものづくり研究などのサークルがあります。学科を越えて参加でき、興味があれば複数の活動を掛け持ちできます。

**一年を通じた交流**（`id: events`）

新入生歓迎会ではサークル紹介やクラス対抗ゲームがあり、競技大会ではクラスの仲間と体を動かします。地域のマラソン大会でのボランティアも、学外の人と関わる機会の一つです。

**普段の昼休み**（`id: everyday`）

学生食堂のRAINBOWは、寮生も自宅などから通う学生も集まる場所です。授業の合間に友人と昼食をとる、普段の学校生活を思い浮かべてみてください。

**地図 `relatedSpots`**

| `canonicalSpotId` | `displayName` |
|---|---|
| `ar` | アリーナ |
| `dh` | 食堂 |

**公式連絡先 `officialContacts`**

| `id` | `kind` | `label` | `url` |
|---|---|---|---|
| `schoolLife` | `web` | サークル・年間イベント | <https://www.jaa-tech.jp/campus-life/schoollife/> |

**編集メモ**

- 参照元　[サークル・年間イベント](https://www.jaa-tech.jp/campus-life/schoollife/)・[学生寮・食堂・売店・体育館](https://www.jaa-tech.jp/campus-life/dormandcafeteria/)
- 意図的に削った項目　年間予定の月日、サークル数、活動曜日の固定。
- 要確認ポイント　紹介する活動や行事の例が現在の学校生活に合っているか。

#### 学生寮（`dormitory`）

- `id`　`dormitory`
- `kind`　`standard`
- `navigationTitle`　学生寮
- `title`　リンドバーグホールとアメリアホール
- `subtitle`　キャンパスにある二つの学生寮の暮らしを紹介します。
- `source`　日本航空大学校公式サイト（https://www.jaa-tech.jp/campus-life/dormandcafeteria/）2026-11-25確認
- `confirmation`　`confirmedOn: "2026-11-25"` ／ `confirmer: "リポジトリオーナー（公式HP照合）"`

**本文 `sections`**

**部屋と食事**（`id: rooms`）

どちらの寮も基本は2人部屋です。寮生は週末も含めて学生食堂で朝・昼・夕の食事がとれます。寮内にはWi-Fiがあり、生活で困ったことは寮監に相談できます。

**リンドバーグホール**（`id: lindbergh`）

大浴場や自習室があります。地図での表示名は「男子寮（リンドバーグホール）」ですが、現在は館内の一部に女子エリアがあり、男女の生活エリアを分けて運用しています。

**アメリアホール**（`id: amelia`）

女子学生の寮です。居室には机付きのロフトベッドがあり、共用の個室シャワーや、洗濯をしながらくつろげる交流スペースがあります。

**地図 `relatedSpots`**

| `canonicalSpotId` | `displayName` |
|---|---|
| `lbh` | 男子寮（リンドバーグホール） |
| `amh` | 女子寮（アメリアホール） |

**公式連絡先 `officialContacts`**

| `id` | `kind` | `label` | `url` |
|---|---|---|---|
| `dormFacilities` | `web` | 学生寮・食堂・売店・体育館 | <https://www.jaa-tech.jp/campus-life/dormandcafeteria/> |

**編集メモ**

- 参照元　[学生寮・食堂・売店・体育館](https://www.jaa-tech.jp/campus-life/dormandcafeteria/)・[施設・設備・機材](https://www.jaa-tech.jp/campus-life/facilities/)
- 意図的に削った項目　収容人数、寮費、個室の空き状況、年度別の運用開始時期。
- 要確認ポイント　地図の正式表示名を保ちつつ、一部女子エリアの運用とアメリアホールとの違いが正確か。

#### よくある質問（FAQ）（`faq`）

- `id`　`faq`
- `kind`　`faq`
- `navigationTitle`　よくある質問（FAQ）
- `title`　オープンキャンパスでよくある質問
- `subtitle`　来校の準備、気になる学科、入学後の暮らしについて。
- `source`　日本航空大学校公式サイト（https://www.jaa-tech.jp/faq/）2026-11-25確認
- `confirmation`　`confirmedOn: "2026-11-25"` ／ `confirmer: "リポジトリオーナー（公式HP照合）"`

**質問と回答 `faqItems`**

太字が `question`、直下の段落が `answerParagraphs[0]` です。

**制服で参加する必要はありますか？**（`id: clothes` ／ `category: 来校準備`）

服装は自由です。屋外での体験に備えて履き慣れた靴を選び、スカートやヒールでの参加はお控えください。

**JR千歳駅から送迎を利用したいときは？**（`id: shuttle` ／ `category: 来校準備`）

オープンキャンパスの参加申込時に、送迎バスの利用も申し込んでください。乗り場は参加する回の案内で確かめてください。

**見学について事前に相談できますか？**（`id: ask` ／ `category: 来校準備`）

オープンキャンパス・学校見学のお問い合わせは、0120-87-8622で受け付けています。

**数学や物理に自信がなくても工学科で学べますか？**（`id: math` ／ `category: 学科選び`）

トータルモビリティ工学科では数学や物理を基礎から学びます。文系出身の学生も在籍しています。

**航空整備科のコースは入学時に決まりますか？**（`id: selection` ／ `category: 学科選び`）

1年次に基礎を学び、コースの説明を受けます。本人の希望する進路、成績、適性を踏まえて、2年次から各コースに分かれます。

**グランドハンドリング科では実際の空港で学べますか？**（`id: airport` ／ `category: 学科選び`）

1年次に新千歳空港でインターンシップに参加します。駐機場での貨物の積み込みを支援するなど、地上の仕事を現場で学びます。

**客室乗務員とグランドスタッフ、入学前にどちらかに決める必要はありますか？**（`id: roles` ／ `category: 学科選び`）

キャビンアテンダント・グランドスタッフ科では、両方の仕事を学びます。就職活動ではどちらの職種にも応募できます。

**旅客サービスに必要な語学はどう学びますか？**（`id: language` ／ `category: 学科選び`）

キャビンアテンダント・グランドスタッフ科では英語を習熟度別のクラスで学び、中国語・韓国語の授業も受けます。

**学生食堂で食物アレルギーについて相談できますか？**（`id: allergy` ／ `category: 学生生活`）

在学生には事前の申請に基づき、食材の変更などに対応しています。来場日の食事については学校に事前に相談し、食べる前にも内容を確認してください。

**寮の食事は週末もありますか？**（`id: meals` ／ `category: 学生生活`）

寮生には土日・祝日も朝昼夕の食事があります。食事をとる場所は学生食堂のRAINBOWです。

**日用品は学内でも買えますか？**（`id: shop` ／ `category: 学生生活`）

食堂に併設された売店で、食品や日用品を扱っています。

**ほかの学科の学生とも交流できますか？**（`id: clubs` ／ `category: 学生生活`）

サークルは学科を越えて参加できます。音楽やスポーツなどから興味のある活動を選べます。新入生歓迎会や競技大会も交流の機会です。

**地図**　`relatedSpots: []`

**公式連絡先 `officialContacts`**

| `id` | `kind` | `label` | `url` |
|---|---|---|---|
| `faq` | `web` | よくあるご質問 | <https://www.jaa-tech.jp/faq/> |
| `visitPhone` | `phone` | オープンキャンパス・学校見学のお問い合わせ（0120-87-8622） | `tel:0120-87-8622` |

**編集メモ**

- 参照元　[よくあるご質問](https://www.jaa-tech.jp/faq/)・[オープンキャンパス](https://www.jaa-tech.jp/opencampus/)・[アクセス](https://www.jaa-tech.jp/campus-life/access/)・[グランドハンドリング科](https://www.jaa-tech.jp/course/technology/)・[学生寮・食堂・売店・体育館](https://www.jaa-tech.jp/campus-life/dormandcafeteria/)・[サークル・年間イベント](https://www.jaa-tech.jp/campus-life/schoollife/)・[お問い合わせ一覧](https://www.jaa-tech.jp/contact-information/)
- 意図的に削った項目　倍率・学費・宿泊料金・人数・時刻表、採用条件の断定。
- 要確認ポイント　12問が当日の来場者に必要な範囲か。食物アレルギーへの対応は来場者にも一律に保証する表現になっていないか。

## Part 2　U-2 建物14棟の説明文（NexusStudio投入待ち）

正式表示名とIDは [E1-1の14棟一覧](../decisions/E1-1-building-canonical-ids.md) に合わせています。Studioの説明欄には「確定した説明文」の列を使います。`null` が確定した4棟は空欄のままにします。その行のURLは、該当する建物固有の説明を特定できなかった照合先です。

| canonical ID | E1-1 正式表示名 | 確定した説明文 | 出典 URL | 備考 |
|---|---|---|---|---|
| `ab` | 管理棟 | `null` 確定 | [施設・設備・機材](https://www.jaa-tech.jp/campus-life/facilities/) | 施設紹介に管理棟の用途の記載が見当たらない。窓口の所在は推測しない。 |
| `amh` | 女子寮（アメリアホール） | 女子学生の寮です。個室シャワーや、洗濯をしながらほかの寮生と過ごせる共用スペースがあります。 | [学生寮・食堂・売店・体育館](https://www.jaa-tech.jp/campus-life/dormandcafeteria/) | 収容人数と空室数は省略。 |
| `aptr` | 機体実習室 | `null` 確定 | [施設・設備・機材](https://www.jaa-tech.jp/campus-life/facilities/) | 機材の紹介からは、この建物にある機材や実習内容を特定できない。 |
| `ar` | アリーナ | バスケットボールやバレーボールなどに使う体育館です。2階にはトレーニングジムがあります。 | [学生寮・食堂・売店・体育館](https://www.jaa-tech.jp/campus-life/dormandcafeteria/)・[施設・設備・機材](https://www.jaa-tech.jp/campus-life/facilities/) | 公式施設図の「ARENA（体育館）」に対応。来場者の利用可否は当日案内。 |
| `ctc_main` | CTC | キャビントレーニングセンターです。旅客機の客室を実物大で再現した訓練設備があります。 | [施設・設備・機材](https://www.jaa-tech.jp/campus-life/facilities/) | 公式施設図のCTCに対応。CTC2とは別棟。 |
| `ctc2` | CTC2 | キャビントレーニングセンター2は、木目を生かした教室棟です。学生が学んだり、くつろいだりできる場所です。 | [施設・設備・機材](https://www.jaa-tech.jp/campus-life/facilities/) | 公式施設図のCTC2に対応。常設の受付を示す記載は省略。 |
| `dh` | 食堂 | 学生食堂RAINBOWは、寮生が毎日の食事をとり、通学生も昼食に利用する場所です。 | [学生寮・食堂・売店・体育館](https://www.jaa-tech.jp/campus-life/dormandcafeteria/) | 席数、当日のメニュー・提供条件は省略。 |
| `dvh` | Da Vinci Hall | キャビンアテンダント・グランドスタッフ科の教室棟です。館内には英語の本をそろえたダヴィンチライブラリーがあります。 | [施設・設備・機材](https://www.jaa-tech.jp/campus-life/facilities/) | 公式施設図の「ダヴィンチホール（教室棟）」に対応。 |
| `hgr_a` | 格納庫A | `null` 確定 | [施設・設備・機材](https://www.jaa-tech.jp/campus-life/facilities/) | 公式の「機体格納庫」はA・Bの区別がない。Aの収容機や用途を特定できない。 |
| `hgr_b` | 格納庫B | `null` 確定 | [施設・設備・機材](https://www.jaa-tech.jp/campus-life/facilities/) | 同じ「機体格納庫」の紹介をBにも当てはめられるか、公式本文では判別できない。 |
| `lbh` | 男子寮（リンドバーグホール） | 大浴場と自習室のある学生寮です。館内の一部に女子エリアを設け、男女の生活エリアを分けています。 | [学生寮・食堂・売店・体育館](https://www.jaa-tech.jp/campus-life/dormandcafeteria/) | 地図の正式表示名と現在の運用を併記。収容人数は省略。 |
| `mb` | 教室棟 | 座学や電気系の実習を行う建物です。大型機について学ぶ実習室もあります。 | [施設・設備・機材](https://www.jaa-tech.jp/campus-life/facilities/) | 公式施設図の「教室棟」に対応。部屋名や階数は省略。 |
| `ptb` | 実習棟 | エンジンの実習や、溶接・板金などの作業を学ぶ建物です。 | [施設・設備・機材](https://www.jaa-tech.jp/campus-life/facilities/) | 公式施設図の「実習棟」に対応。地図上の入口や経路は説明に含めない。 |
| `sab` | 技能審査棟 | 航空整備科の学生が国家資格の取得に向けて技能審査を受ける会場です。 | [施設・設備・機材](https://www.jaa-tech.jp/campus-life/facilities/) | 審査日や当日の見学可否は省略。 |

## Part 3　募集部への任意確認依頼文

原稿を添えてお送りください。文面では返信期限を送付から1週間としています。

**件名　オープンキャンパス来場者向けアプリ「Nexus」掲載文のご確認（任意）**

募集部の皆さま

オープンキャンパスの来場者が、当日の動き方や学科、学生生活をスマートフォンで確認できるよう、学校公式サイトをもとにアプリ「Nexus」の掲載案を作成しました。案内10記事と、キャンパスマップに表示する建物の説明案をお送りします。

学科・コース名、学生寮の利用区分、施設の用途や問い合わせ先について、修正や掲載を控えてほしい箇所がありましたら、このご連絡から1週間以内に、記事名または建物名と該当箇所をお知らせください。

ご確認は任意です。期限までにご要望がなければ、公式サイトで確認できた内容をオーナーが最終確認のうえ掲載します。建物の用途を確認できなかった箇所は空欄とします。後日ご要望をいただいた場合も、アプリの更新で反映いたします。

どうぞよろしくお願いいたします。
