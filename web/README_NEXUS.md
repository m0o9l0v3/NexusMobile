# Nexus Campus PWA - オープンキャンパス来場者向けアプリ

> [!IMPORTANT]
> この文書は、イベント告知 LP への再構成前に作られた参加者向け PWA プロトタイプの設計・再利用資料です。v1.0 の正式な参加者向けアプリ機能は iOS に限定し、`web/` はイベント告知・当日案内・iOS アプリへの導線を担う LP とします。製品方針は [Work item #7](https://gitlab.com/11h27m/nexus-mobile/-/work_items/7)、LP の実装と QR 挙動は [Work item #81](https://gitlab.com/11h27m/nexus-mobile/-/work_items/81) を参照してください。

Material Design 3準拠、青空トーンの大学オープンキャンパス向けモバイルPWAです。

## 🌐 ブラウザ対応

**対応ブラウザ**: iOS Safari 14+, Android Chrome 90+, Firefox Mobile, その他モダンブラウザ

詳細は [BROWSER_COMPATIBILITY.md](./BROWSER_COMPATIBILITY.md) を参照してください。

## 🎨 デザインコンセプト

**「終わりのない青空」** - 穏やかで広がりのある空をイメージした、控えめで優しいデザイン

### 主要な特徴
- **淡い空色グラデーション:** 背景に使用し、落ち着いた雰囲気を演出
- **大きな角丸 + 控えめな影:** カードが浮いている質感
- **色面積の抑制:** 混雑表示も派手にせず、枠線と薄い背景で表現
- **片手操作最適化:** 390px幅、主要アクションは下部に配置

## 📱 画面構成

### 1. ホーム画面
- ヒーローセクション（空色グラデーション背景）
- **「キャンパスマップを開く」** プライマリCTA
- 次のイベント一覧（3件）
- おすすめスポット（2件、2カラムグリッド）

### 2. マップ画面
- **フルスクリーン2Dマップ**（プレースホルダーSVG）
- トップバー: 検索バー + フロア切替（Outdoor/B1/1F/2F/3F）
- 右サイド: ズームコントロール + 混雑フィルタ
- **Bottom Sheet（5つの状態）:**
  1. **Idle:** ハンドル + ヒントテキスト
  2. **Search:** カテゴリチップ + 検索結果リスト
  3. **Spot Detail:** タイトル、タグ、混雑バッジ、アクション3つ
  4. **Route:** 経路案内（所要時間、次の移動、ステップバイステップ）
  5. **Filters:** カテゴリ、混雑、営業中、バリアフリー

### 3. イベント画面
- ヘッダー: フィルタチップ（カテゴリ、学部）
- タイムライン: 時間ごとにグループ化
- イベントカード: タップで詳細をBottom Sheetで表示

### Bottom Navigation（3タブのみ）
1. **ホーム** - 概要とクイックアクセス
2. **マップ** - キャンパス2D地図
3. **イベント** - スケジュール一覧

## 🎯 主要コンポーネント

### MapCanvas
- グリッドプレースホルダー + フロア別SVGマップ
- スポットマーカー（混雑リング付き）
- ルート線表示（破線、アニメーション）

### CongestionBadge
- **4レベル:** 空（緑）、普（黄）、混（橙）、満（赤）
- **サイズ:** default / small
- **デザイン:** 枠線 + 薄い背景（色面積抑制）

### MapMarker
- **外側リング:** 混雑状態を色で表現、選択時はパルスアニメーション
- **内側ドット:** 出発地（青）、目的地（赤）、通常（白）
- **ホバー:** ツールチップでスポット名表示

### FloorSwitch
- セグメントコントロール（Material 3）
- アクティブフロアにピル背景
- layoutId による滑らかな遷移

### Bottom Sheet（5状態バリアント）
- **Idle:** 120px、最小表示
- **Search/Filters:** 50vh
- **Spot Detail:** 自動高さ
- **Route:** 60vh
- スワイプジェスチャー対応

### EventCard
- 時刻バッジ（左側、48px幅）
- タイトル、場所、学部、説明文
- タップでBottom Sheet詳細表示

## 🔧 技術スタック

- **React 18.3** - UI構築
- **TypeScript** - 型安全性
- **Tailwind CSS v4** - スタイリング
- **Motion (Framer Motion後継)** - アニメーション
- **Lucide React** - アイコン
- **Material Design 3** - デザインシステム

## 🎨 デザイントークン

### カラーパレット
```css
--sky-0: #F4FBFF        /* 最淡空色 */
--sky-1: #DDF1FF        /* 淡空色 */
--primary: #0B5ED7      /* プライマリブルー */
--primary-weak: #A7D8FF /* プライマリ淡色 */
--text: #0B1B3A         /* テキスト */
--surface: #FFFFFF      /* カード背景 */
```

### 混雑カラー
```css
--congestion-empty: #34A853   /* 空 */
--congestion-normal: #FBBC04  /* 普 */
--congestion-busy: #FF9800    /* 混 */
--congestion-full: #EA4335    /* 満 */
```

### Elevation（Material 3）
- **elev-1:** 0 1px 2px rgba(11, 27, 58, 0.06)
- **elev-2:** 0 2px 8px rgba(11, 27, 58, 0.08), 0 1px 3px rgba(11, 27, 58, 0.06)
- **elev-3:** 0 4px 16px rgba(11, 27, 58, 0.10), 0 2px 6px rgba(11, 27, 58, 0.08)

### タイポグラフィ
- **フォント:** Noto Sans JP + Inter
- **特徴:** タブラー数字（距離、時間用）
- **スケール:** h1(24px) → h4(16px) → body(16px) → small(12px)

## 📐 レイアウトルール

### スペーシング（8dpグリッド）
- xs: 4px, sm: 8px, md: 12px, lg: 16px, xl: 24px, 2xl: 32px

### 角丸
- sm: 8px, md: 12px, lg: 16px, xl: 24px, full: 9999px

### タップターゲット
- **最小:** 44x44px
- **推奨:** 48x48px（プライマリアクション）

## ♿ アクセシビリティ

- **prefers-reduced-motion:** アニメーション時間を0.01msに短縮
- **コントラスト比:** WCAG AA準拠
- **セーフエリア:** ノッチ対応（safe-area-inset-bottom）
- **タブラー数字:** 数値の可読性向上

## 📂 ファイル構造

```
src/
├── app/
│   ├── App.tsx                    # メインアプリ（3画面切替）
│   └── components/
│       ├── HomeScreen.tsx         # ホーム画面
│       ├── MapScreen.tsx          # マップ画面
│       ├── EventsScreen.tsx       # イベント画面
│       ├── MapCanvas.tsx          # マップキャンバス
│       ├── MapMarker.tsx          # スポットマーカー
│       ├── MapBottomSheet.tsx     # マップ用Bottom Sheet（5状態）
│       ├── BottomSheet.tsx        # 汎用Bottom Sheet
│       ├── BottomNav.tsx          # 下部ナビゲーション（3タブ）
│       ├── FloorSwitch.tsx        # フロア切替
│       ├── CongestionBadge.tsx    # 混雑バッジ
│       ├── CongestionFilter.tsx   # 混雑フィルタパネル
│       ├── RouteStepChip.tsx      # ルートステップチップ
│       ├── SuggestListItem.tsx    # 検索サジェストアイテム
│       ├── LoadingState.tsx       # ローディング状態
│       └── DesignSystemGuide.tsx  # デザインシステムガイド
├── styles/
│   ├── fonts.css                  # フォントインポート
│   ├── theme.css                  # カラートークン + Material 3設定
│   ├── index.css                  # メインスタイル
│   └── tailwind.css               # Tailwind設定
└── ...
```

## 🚀 主要機能

### マップ機能
- ✅ フロア別表示（Outdoor/B1/1F/2F/3F）
- ✅ スポット検索（カテゴリフィルタ付き）
- ✅ 混雑状況表示（4レベル）
- ✅ 経路案内（ステップバイステップ）
- ✅ ズーム操作（+/- ボタン）
- ✅ 混雑フィルタ（プリセット含む）

### イベント機能
- ✅ タイムライン表示（時間ごとにグループ化）
- ✅ カテゴリフィルタ（説明会、ツアー、模擬授業等）
- ✅ 学部フィルタ（工学部、情報学部等）
- ✅ イベント詳細（Bottom Sheet）
- ✅ マップへのナビゲーション

### ホーム機能
- ✅ 次のイベント表示（3件）
- ✅ おすすめスポット（2件）
- ✅ マップへのクイックアクセス

## 🎬 アニメーション仕様

### 原則
- **物理ベース:** Spring physics（stiffness: 300, damping: 30）
- **期間:** 200-300ms（状態変化）
- **GPU最適化:** transform と opacity のみ使用

### 主要アニメーション
- **Bottom Sheet:** 下からスライドイン
- **Bottom Nav:** Active背景のシェアードエレメント遷移
- **Map Marker:** 選択時のパルスアニメーション
- **Floor Switch:** 背景のスムーズな移動
- **Route Line:** 経路の描画アニメーション（pathLength）

## 🔄 状態管理

### 画面遷移
```tsx
activeTab: 'home' | 'map' | 'events'
```

### Bottom Sheet状態
```tsx
mode: 'idle' | 'search' | 'spot' | 'route' | 'filters'
```

### フィルタ状態
```tsx
selectedCongestionLevels: ('empty' | 'normal' | 'busy' | 'full')[]
selectedCategory: string
selectedDepartment: string
```

## 📊 モックデータ

### スポット
- 10か所（受付、講義室、図書館、カフェテリア等）
- 各スポット: ID、名前、フロア、座標、混雑、カテゴリ、タグ

### イベント
- 7イベント（受付開始、説明会、ツアー、模擬授業等）
- 各イベント: ID、タイトル、時間、場所、学部、カテゴリ、説明

## 🌐 Material Design 3準拠項目

- ✅ Color roles（Primary, Surface, Outline等）
- ✅ Elevation system（3レベル）
- ✅ State layers（Hover, Pressed）
- ✅ Typography scale
- ✅ Shape system（大きな角丸）
- ✅ Motion patterns（Spring physics）
- ✅ Component patterns（Bottom Sheet, Segmented Control等）

## 📱 レスポンシブ対応

- **ベース:** 390x844px（iPhone 12/13 Pro）
- **最大幅:** 390px（デスクトップでは中央配置）
- **セーフエリア:** ノッチ対応
- **片手操作:** 下部に主要アクション配置

## 🎯 今後の拡張案

- [ ] 実際のSVGマップデータの組み込み
- [ ] Server-Sent Events（SSE）による混雑情報のリアルタイム更新
- [ ] 位置情報サービス連携（現在地表示）
- [ ] オフラインサポート（PWA機能）
- [ ] 多言語対応（英語、中国語等）
- [ ] ダークモード対応
- [ ] お気に入り機能の永続化
- [ ] プッシュ通知（イベント開始前のリマインド）

## 📖 参考資料

- [Material Design 3](https://m3.material.io/)
- [Apple Human Interface Guidelines - Mobile](https://developer.apple.com/design/human-interface-guidelines/)
- [WCAG 2.1 Guidelines](https://www.w3.org/WAI/WCAG21/quickref/)

---

**バージョン:** 1.0  
**作成日:** 2026年1月29日  
**ライセンス:** MIT
