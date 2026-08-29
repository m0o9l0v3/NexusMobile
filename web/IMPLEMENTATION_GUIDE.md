# Nexus Campus PWA - 実装ガイド

## 📋 概要

このガイドでは、Nexus Campus PWAの実装方法と、各コンポーネントの使用方法について説明します。

## 🎯 実装完了項目

### ✅ A) デザインシステム生成

**完了内容:**
- Material Design 3準拠のカラーシステム
- 青空トーンの淡いグラデーション背景
- 大きな角丸 + 控えめな影
- 8dpスペーシンググリッド
- 日本語UI最適化のタイポグラフィ

**ファイル:**
- `/src/styles/theme.css` - カラートークン定義
- `/src/styles/fonts.css` - フォントインポート（Noto Sans JP + Inter）
- `/DESIGN_SYSTEM.md` - 完全なデザインシステムドキュメント

### ✅ B) 主要3画面（Home / Map / Events）

**完了内容:**
- 3つのメイン画面を実装
- 下部ナビゲーション（4タブ: Home, Map, Info, Schedule。Info / Scheduleは準備中）
- 各画面の機能要件を完全実装

**ファイル:**
- `/src/app/components/HomeScreen.tsx`
- `/src/app/components/MapScreen.tsx`
- `/src/app/components/EventsScreen.tsx`
- `/src/app/components/BottomNav.tsx`

### ✅ C) MapのBottom Sheet（状態バリアント）

**完了内容:**
- 5つの状態バリアントを実装
  1. Idle - ハンドル + ヒント
  2. Search - 検索結果リスト
  3. Spot Detail - スポット詳細
  4. Route - 経路案内
  5. Filters - フィルタ設定

**ファイル:**
- `/src/app/components/MapBottomSheet.tsx`
- `/src/app/components/BottomSheet.tsx`

## 🏗️ アーキテクチャ

### ディレクトリ構造

```
src/
├── app/
│   ├── App.tsx                      # メインアプリケーション
│   └── components/
│       ├── HomeScreen.tsx           # ホーム画面
│       ├── MapScreen.tsx            # マップ画面
│       ├── EventsScreen.tsx         # イベント画面
│       ├── WelcomeScreen.tsx        # ウェルカム画面（オプション）
│       ├── DesignShowcase.tsx       # デザインシステムショーケース
│       │
│       ├── MapCanvas.tsx            # マップキャンバス
│       ├── MapMarker.tsx            # マップマーカー
│       ├── MapBottomSheet.tsx       # マップ用Bottom Sheet（5状態）
│       ├── BottomSheet.tsx          # 汎用Bottom Sheet
│       │
│       ├── BottomNav.tsx            # 下部ナビゲーション（4タブ）
│       ├── FloorSwitch.tsx          # フロア切替
│       ├── CongestionBadge.tsx      # 混雑バッジ
│       ├── CongestionFilter.tsx     # 混雑フィルタパネル
│       ├── RouteStepChip.tsx        # ルートステップチップ
│       ├── SuggestListItem.tsx      # 検索サジェストアイテム
│       └── LoadingState.tsx         # ローディング状態
│
└── styles/
    ├── fonts.css                    # フォント定義
    ├── theme.css                    # カラートークン + Material 3設定
    ├── index.css                    # メインスタイル
    └── tailwind.css                 # Tailwind設定
```

### 状態管理

```tsx
// メイン画面の状態
const [activeTab, setActiveTab] = useState<'home' | 'map' | 'events'>('home');

// Bottom Sheetの状態
const [isBottomSheetOpen, setIsBottomSheetOpen] = useState(false);
const [bottomSheetMode, setBottomSheetMode] = useState<'idle' | 'search' | 'spot' | 'route' | 'filters'>('idle');

// フィルタの状態
const [selectedCongestionLevels, setSelectedCongestionLevels] = useState<CongestionLevel[]>([
  'empty', 'normal', 'busy', 'full'
]);
```

## 📱 各画面の実装詳細

### 1. ホーム画面（HomeScreen）

**機能:**
- ヒーローセクション（青空グラデーション）
- 「キャンパスマップを開く」プライマリCTA
- 次のイベント一覧（3件）
- おすすめスポット（2件、2カラムグリッド）

**使用方法:**
```tsx
<HomeScreen
  onOpenMap={() => setActiveTab('map')}
  onEventClick={(event) => handleEventClick(event)}
  onSpotClick={(spot) => handleSpotClick(spot)}
/>
```

**Props:**
- `onOpenMap`: マップを開くコールバック
- `onEventClick`: イベントクリック時のコールバック
- `onSpotClick`: スポットクリック時のコールバック

### 2. マップ画面（MapScreen）

**機能:**
- Figma準拠のフルスクリーン地図（現在は画像レンダラー、将来Mapboxへ置換予定）
- ロゴ付き検索バー、現在地ボタン、全画面検索入力
- 通常時はマーカー・フロア切替・混雑フィルタを非表示
- サポート地点選択や外部フォーカス時のみ、既存マーカーとフロア切替を表示
- 地図描画は`MapCanvas`、検索・ボタン等のUIは`MapScreen`に分離

**使用方法:**
```tsx
<MapScreen
  spots={mockSpots}
  onSpotClick={(spot) => handleSpotClick(spot)}
/>
```

**Props:**
- `spots`: 表示するスポットの配列
- `onSpotClick`: スポットクリック時のコールバック

**状態:**
- `currentFloor`: 現在表示中のフロア
- `zoomLevel`: ズームレベル（0.5〜2）
- `bottomSheetMode`: Bottom Sheetの現在のモード

### 3. イベント画面（EventsScreen）

**機能:**
- ヘッダー: フィルタチップ（カテゴリ、学部）
- タイムライン: 時間ごとにグループ化
- イベントカード: タップで詳細をBottom Sheetで表示
- フィルタボタン: 学部フィルタの表示/非表示

**使用方法:**
```tsx
<EventsScreen
  onEventClick={(event) => handleEventClick(event)}
/>
```

**Props:**
- `onEventClick`: イベントクリック時のコールバック

**状態:**
- `selectedCategory`: 選択中のカテゴリ
- `selectedDepartment`: 選択中の学部
- `isFilterOpen`: フィルタパネルの開閉状態

## 🔧 コンポーネントの使用方法

### CongestionBadge（混雑バッジ）

**用途:** 混雑状況を視覚的に表示

```tsx
<CongestionBadge level="empty" />       // 空
<CongestionBadge level="normal" />      // 普
<CongestionBadge level="busy" />        // 混
<CongestionBadge level="full" />        // 満

// Small variant
<CongestionBadge level="empty" variant="small" />
```

**Props:**
- `level`: 混雑レベル（'empty' | 'normal' | 'busy' | 'full'）
- `variant`: サイズ（'default' | 'small'）

**スタイル特徴:**
- 低色面積（背景10%透明度）
- 枠線で視認性確保
- 日本語1文字表示

### FloorSwitch（フロア切替）

**用途:** フロアの切り替え

```tsx
<FloorSwitch
  floors={['Outdoor', 'B1', '1F', '2F', '3F']}
  currentFloor={currentFloor}
  onFloorChange={(floor) => setCurrentFloor(floor)}
/>
```

**Props:**
- `floors`: フロアの配列
- `currentFloor`: 現在選択中のフロア
- `onFloorChange`: フロア変更時のコールバック

**アニメーション:**
- `layoutId="floor-active-bg"` によるシェアードエレメント遷移
- Spring physics（stiffness: 300, damping: 30）

### MapBottomSheet（マップ用Bottom Sheet）

**用途:** マップ画面でのコンテキスト表示

```tsx
<MapBottomSheet
  isOpen={isOpen}
  mode="spot"
  spot={selectedSpot}
  onClose={() => setIsOpen(false)}
  onNavigate={(spot) => handleNavigate(spot)}
  onViewEvents={(spot) => handleViewEvents(spot)}
  onFavorite={(spot) => handleFavorite(spot)}
/>
```

**Props:**
- `isOpen`: 開閉状態
- `mode`: 表示モード（'idle' | 'search' | 'spot' | 'route' | 'filters'）
- `spot`: 表示するスポット（mode='spot'の場合）
- `routeInfo`: 経路情報（mode='route'の場合）
- `searchResults`: 検索結果（mode='search'の場合）
- `onClose`: 閉じる時のコールバック
- その他アクション用コールバック

**モード別の高さ:**
- `idle`: 120px
- `search`, `filters`: 50vh
- `spot`: auto（コンテンツに応じる）
- `route`: 60vh

### MapMarker（マップマーカー）

**用途:** マップ上のスポット表示

```tsx
<MapMarker
  spot={spot}
  isSelected={selectedSpot?.id === spot.id}
  onClick={() => handleSpotClick(spot)}
/>
```

**Props:**
- `spot`: スポット情報
- `isSelected`: 選択状態
- `onClick`: クリック時のコールバック

**視覚要素:**
- 外側リング: 混雑状態を色で表現（選択時はパルスアニメーション）
- 内側ドット: 出発地（青）、目的地（赤）、通常（白）
- ホバー時: ツールチップでスポット名表示

### BottomNav（下部ナビゲーション）

**用途:** メイン画面間の遷移

```tsx
<BottomNav
  activeTab={activeTab}
  onTabChange={(tab) => setActiveTab(tab)}
/>
```

**Props:**
- `activeTab`: 現在アクティブなタブ
- `onTabChange`: タブ変更時のコールバック

**タブ:**
1. Home - ホーム
2. Map - マップ
3. Info - 情報（準備中）
4. Schedule - 時間割（準備中）

既存の`EventsScreen`は削除せず、下部ナビからは直接遷移しません。

## 🎨 デザイントークンの使用

### カラーの適用

```tsx
// Primary color
<button style={{ backgroundColor: 'var(--primary)', color: 'var(--primary-foreground)' }}>
  ボタン
</button>

// Surface with elevation
<div style={{ backgroundColor: 'var(--surface)', boxShadow: 'var(--elev-2)' }}>
  カード
</div>

// Congestion color
<div style={{ backgroundColor: 'var(--congestion-empty)' }}>
  混雑状態
</div>
```

### スペーシングの適用

```tsx
// Tailwind classes使用
<div className="p-4">      // 16px padding
<div className="gap-3">    // 12px gap
<div className="mb-6">     // 24px margin-bottom

// 直接指定
<div style={{ padding: '1rem' }}>  // 16px
```

### 角丸の適用

```tsx
<div className="rounded-2xl">  // 16px
<div className="rounded-3xl">  // 24px
<div className="rounded-full"> // 完全な円形
```

## 🎬 アニメーションの実装

### ボタンのタップアニメーション

```tsx
import { motion } from 'motion/react';

<motion.button
  whileTap={{ scale: 0.98 }}
  style={{
    backgroundColor: 'var(--primary)',
    color: 'var(--primary-foreground)',
  }}
>
  タップ可能なボタン
</motion.button>
```

### 要素の出現アニメーション

```tsx
<motion.div
  initial={{ opacity: 0, y: 20 }}
  animate={{ opacity: 1, y: 0 }}
  transition={{ duration: 0.3 }}
>
  コンテンツ
</motion.div>
```

### シェアードエレメント遷移

```tsx
<motion.div
  layoutId="unique-id"
  className="..."
  transition={{ type: 'spring', stiffness: 300, damping: 30 }}
>
  遷移する要素
</motion.div>
```

### アクセシビリティ対応（prefers-reduced-motion）

自動的に対応済み。`/src/styles/index.css` に以下が定義されています:

```css
@media (prefers-reduced-motion: reduce) {
  * {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
  }
}
```

## 📊 データ型定義

### Spot型

```tsx
type Spot = {
  id: string;
  name: string;
  floor: string;
  x: number;              // マップ上のX座標（%）
  y: number;              // マップ上のY座標（%）
  congestion: 'empty' | 'normal' | 'busy' | 'full';
  category: string;
  distance?: number;      // 距離（メートル）
  tags?: string[];        // タグ
  relatedEvents?: number; // 関連イベント数
  isDestination?: boolean;
  isOrigin?: boolean;
};
```

### Event型

```tsx
type Event = {
  id: string;
  title: string;
  time: string;           // 開始時刻（HH:MM形式）
  endTime?: string;       // 終了時刻
  location: string;
  floor?: string;
  department: string;
  category?: string;
  description?: string;
};
```

### RouteInfo型

```tsx
type RouteInfo = {
  distance: number;       // 総距離（メートル）
  duration: number;       // 所要時間（分）
  nextFloor?: string;     // 次のフロア
  nextLandmark?: string;  // 次のランドマーク
  steps: Array<{
    floor: string;
    landmark: string;
    distance: number;
  }>;
};
```

## 🔄 画面遷移フロー

### 基本フロー

```
[Welcome Screen] (初回のみ)
    ↓ (「はじめる」タップ)
[Home Screen]
    ↓ (「キャンパスマップを開く」タップ)
[Map Screen]
    ↓ (スポットタップ)
[Map Screen + Bottom Sheet (Spot Detail)]
    ↓ (「案内」タップ)
[Map Screen + Bottom Sheet (Route)]
```

### イベントからマップへのフロー

```
[Events Screen]
    ↓ (イベントカードタップ)
[Events Screen + Bottom Sheet (Event Detail)]
    ↓ (「マップで見る」タップ)
[Map Screen] (該当スポットが選択された状態)
```

## 🧪 テスト・デバッグ用

### デザインシステムショーケースの表示

App.tsxを一時的に以下に変更:

```tsx
import { DesignShowcase } from '@/app/components/DesignShowcase';

export default function App() {
  return <DesignShowcase />;
}
```

これにより、全てのデザインシステムコンポーネントを一覧表示できます。

### ウェルカム画面のテスト

```tsx
import { useState } from 'react';
import { WelcomeScreen } from '@/app/components/WelcomeScreen';
import { HomeScreen } from '@/app/components/HomeScreen';

export default function App() {
  const [showWelcome, setShowWelcome] = useState(true);
  
  if (showWelcome) {
    return <WelcomeScreen onStart={() => setShowWelcome(false)} />;
  }
  
  return <HomeScreen {...props} />;
}
```

## 📝 カスタマイズガイド

### 新しいフロアの追加

1. `floors` 配列に追加:
```tsx
const floors = ['Outdoor', 'B1', '1F', '2F', '3F', '4F']; // 4F追加
```

2. そのフロアのスポットデータを追加:
```tsx
{ id: '11', name: '新スポット', floor: '4F', ... }
```

### 新しい混雑レベルの追加

1. `theme.css` にカラー追加:
```css
--congestion-critical: #C62828; /* 緊急レベル */
```

2. `CongestionBadge.tsx` の設定に追加:
```tsx
const congestionConfig = {
  // ... 既存の設定
  critical: {
    label: '緊',
    color: 'var(--congestion-critical)',
    bg: 'rgba(198, 40, 40, 0.1)',
  },
};
```

### 新しいカテゴリの追加

`categories` 配列に追加:
```tsx
const categories = ['全て', '教室', '施設', '食堂', '休憩', '移動', '相談室'];
```

## 🚀 本番環境への展開

### 1. 環境変数の設定

`.env.production`:
```
VITE_API_URL=https://api.example.com
VITE_MAP_TILES_URL=https://tiles.example.com
```

### 2. ビルド

```bash
npm run build
```

### 3. PWA対応

`manifest.json` と service worker の追加が必要です（現在未実装）。

### 4. パフォーマンス最適化

- 画像の最適化（WebP形式）
- コード分割（React.lazy）
- SSRの検討（Next.js等）

## ❓ よくある質問

### Q: モバイルデバイスでテストするには？

A: Chrome DevToolsのデバイスモードを使用するか、実機でローカルネットワーク経由でアクセス:
```bash
npm run dev -- --host
```

### Q: アニメーションを完全に無効化するには?

A: ブラウザの設定で「動きを減らす」を有効にするか、CSSに以下を追加:
```css
* {
  animation: none !important;
  transition: none !important;
}
```

### Q: Mapboxへ移行するには?

A: `MapCanvas.tsx`の画像・パン操作実装をMapboxレンダラーへ置き換えます。検索バー、現在地ボタン、下部ナビ、`supportPickMode`などのUI契約は`MapScreen`側に分離されているため維持します。Figmaの地図画像は移行期間中のフォールバック／表示比較用として扱います。

## 📚 関連ドキュメント

- [DESIGN_SYSTEM.md](./DESIGN_SYSTEM.md) - 完全なデザインシステム仕様
- [README_NEXUS.md](./README_NEXUS.md) - プロジェクト概要
- [Material Design 3 Guidelines](https://m3.material.io/)

---

**最終更新:** 2026年1月29日
