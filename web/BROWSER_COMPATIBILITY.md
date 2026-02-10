# Nexus PWA - Browser Compatibility Guide

## 対応ブラウザ
- iOS Safari (iOS 14+)
- Android Chrome (Chrome 90+)
- Firefox Mobile
- その他モダンブラウザ

## 設計思想

### Progressive Enhancement
重要な機能とUIは**すべてのブラウザで動作**することを前提とし、追加の視覚効果は対応ブラウザでのみ有効化します。

### ベースUI（全ブラウザ共通）
- フラットな背景色
- シンプルな影
- 基本的なトランジション
- position: fixed での固定要素

### 拡張UI（対応ブラウザのみ）
- backdrop-filter（ぼかし効果）
- 複雑なアニメーション
- 高度な影表現

## 主要な技術的対応

### 1. Viewport Height問題
**問題**: iOS Safariでアドレスバーが100vhに含まれ、スクロール時に表示が崩れる

**解決策**:
```css
height: 100vh;
height: 100dvh; /* Dynamic viewport height - 対応ブラウザで上書き */
```

### 2. Safe Area対応
**iOS Safariのノッチ/ホームバー対策**:
```css
/* BottomNav */
paddingBottom: max(8px, env(safe-area-inset-bottom));

/* コンテンツエリア */
paddingBottom: calc(80px + max(8px, env(safe-area-inset-bottom)));
```

### 3. Position Fixed vs Absolute
**BottomNav**: `position: fixed` + `bottom: 0`
- Safariでもスクロール時に固定される
- Chromeでも常に表示される
- スクロール時のちらつきを防止

**コンテンツエリア**: 適切な`padding-bottom`で余白を確保
- BottomNavの高さ（約72px）
- Safe area inset
- 追加の視覚的余白（8px）

### 4. スクロール最適化
```css
-webkit-overflow-scrolling: touch; /* iOS慣性スクロール */
scrollbar-width: none; /* スクロールバー非表示 */
```

## 実装パターン

### コンポーネント別対応

#### BottomNav
```tsx
<div 
  className="fixed left-0 right-0 z-50"
  style={{
    bottom: 0,
    paddingBottom: 'max(8px, env(safe-area-inset-bottom))',
  }}
>
```

#### 各画面（HomeScreen, EventsScreen）
```tsx
<div 
  className="h-full overflow-y-auto"
  style={{
    paddingBottom: 'calc(80px + max(8px, env(safe-area-inset-bottom)))',
  }}
>
```

#### App.tsx（ルートコンテナ）
```tsx
<div 
  style={{ 
    height: '100vh',
    height: '100dvh', // フォールバック戦略
  }}
>
```

## テスト観点

### Safari (iOS)
- [ ] BottomNavがホームバーと重ならない
- [ ] アドレスバー表示/非表示時にレイアウトが崩れない
- [ ] スクロール時にBottomNavが固定される
- [ ] ノッチ領域に要素が入らない

### Chrome (Android/Desktop)
- [ ] BottomNavが常に表示される
- [ ] スクロール時に要素が隠れない
- [ ] アドレスバー変化時もレイアウトが維持される

### Firefox Mobile
- [ ] 基本的なレイアウトが維持される
- [ ] アニメーションが動作する（または安全にフォールバック）

## よくある問題と解決策

### Q: Chromeでボトムバーが隠れる
**原因**: `position: absolute` + 不適切な親要素の高さ設定
**解決**: `position: fixed` + `bottom: 0` + Safe area対応

### Q: Safariでスクロール時にレイアウトが崩れる
**原因**: 100vh問題、safe-area未対応
**解決**: dvh使用、env(safe-area-inset-*)の適用

### Q: 一部のブラウザで影やぼかしが効かない
**原因**: backdrop-filterなど新しいCSSの未対応
**対応**: Progressive Enhancement - ベースUIは機能する設計

## CSS Feature Detection（参考）

将来的により高度な機能を追加する場合は、以下のような検出を使用：

```css
/* backdrop-filter対応チェック */
@supports (backdrop-filter: blur(10px)) {
  .enhanced-bg {
    backdrop-filter: blur(10px);
  }
}

/* フォールバック */
@supports not (backdrop-filter: blur(10px)) {
  .enhanced-bg {
    background-color: rgba(255, 255, 255, 0.95);
  }
}
```

## まとめ

- **ベースUIは全ブラウザで動作**
- **Safe Areaを常に考慮**
- **100vh/100dvhの両方を記述**
- **固定要素はfixedを使用**
- **Progressive Enhancementの原則**
