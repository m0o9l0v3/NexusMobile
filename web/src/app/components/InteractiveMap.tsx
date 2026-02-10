import { useRef, useEffect, useCallback } from 'react';
import { motion, useMotionValue, useTransform } from 'motion/react';
import { MapMarker } from '@/app/components/MapMarker';

type Spot = {
  id: string;
  name: string;
  floor: string;
  x: number;
  y: number;
  congestion: 'empty' | 'normal' | 'busy' | 'full';
  category: string;
  isDestination?: boolean;
  isOrigin?: boolean;
};

type Route = {
  from: Spot;
  to: Spot;
  currentFloor: string;
};

type InteractiveMapProps = {
  currentFloor: string;
  spots: Spot[];
  selectedSpot?: Spot;
  route?: Route;
  onSpotClick?: (spot: Spot) => void;
  initialScale?: number;
  initialX?: number;
  initialY?: number;
};

// ユーティリティ: 2点間の距離を計算
const getDistance = (t1: React.Touch, t2: React.Touch) => {
  return Math.hypot(t2.clientX - t1.clientX, t2.clientY - t1.clientY);
};

// ユーティリティ: 2点の中点を計算
const getCenter = (t1: React.Touch, t2: React.Touch) => {
  return {
    x: (t1.clientX + t2.clientX) / 2,
    y: (t1.clientY + t2.clientY) / 2,
  };
};

export function InteractiveMap({ 
  currentFloor, 
  spots, 
  selectedSpot, 
  route,
  onSpotClick,
  initialScale = 1,
  initialX = 0,
  initialY = 0,
}: InteractiveMapProps) {
  const containerRef = useRef<HTMLDivElement>(null);
  const contentRef = useRef<HTMLDivElement>(null);

  // --- State Management (Motion Values for Performance) ---
  // ReactのState更新(re-render)を介さず、直接DOMを操作するためにMotionValueを使用
  const x = useMotionValue(initialX);
  const y = useMotionValue(initialY);
  const scale = useMotionValue(initialScale);
  
  // マーカーの逆スケール（地図が拡大してもマーカーサイズを維持または調整）
  const markerScale = useTransform(scale, s => 1 / Math.max(0.5, s));

  // --- Internal Logic State (Refs) ---
  // イベントハンドラ内で参照・更新するための可変な値
  const state = useRef({
    isDragging: false,
    isPinching: false,
    isMouseDn: false,
    
    // パン操作用
    lastTouchX: 0,
    lastTouchY: 0,
    
    // ピンチ操作用
    startDist: 0,
    startScale: 1,
    startPinchCenter: { x: 0, y: 0 }, // 画面上の中心座標
    startTx: 0, // ピンチ開始時のマップ位置 x
    startTy: 0, // ピンチ開始時のマップ位置 y
  });

  // 設定定数
  const MIN_ZOOM = 0.5;
  const MAX_ZOOM = 5.0;

  // ------------------------------------------------------------------
  // Touch Handlers (Smartphone / Tablet)
  // Pointer Eventsではなく、Touch Eventsを直接扱うことでOSの挙動干渉を防ぐ
  // ------------------------------------------------------------------

  const handleTouchStart = (e: React.TouchEvent) => {
    // 2本指以上の操作時は、ブラウザバックなどのジェスチャを防ぐ
    if (e.touches.length >= 2) {
      e.preventDefault();
    }

    if (e.touches.length === 1) {
      // --- 1本指: パン開始 ---
      state.current.isDragging = true;
      state.current.isPinching = false;
      state.current.lastTouchX = e.touches[0].clientX;
      state.current.lastTouchY = e.touches[0].clientY;
      
    } else if (e.touches.length === 2) {
      // --- 2本指: ピンチ開始 ---
      state.current.isDragging = false;
      state.current.isPinching = true;
      
      const t1 = e.touches[0];
      const t2 = e.touches[1];
      
      state.current.startDist = getDistance(t1, t2);
      state.current.startScale = scale.get();
      state.current.startPinchCenter = getCenter(t1, t2);
      state.current.startTx = x.get();
      state.current.startTy = y.get();
    }
  };

  const handleTouchMove = (e: React.TouchEvent) => {
    // デフォルトのスクロール動作等を完全に無効化（MapViewport内でのみ）
    if (e.cancelable) e.preventDefault();
    e.stopPropagation();

    if (state.current.isDragging && e.touches.length === 1) {
      // --- 1本指: パン実行 ---
      // 指の移動量 = マップの移動量 (吸い付き感��視)
      const touch = e.touches[0];
      const dx = touch.clientX - state.current.lastTouchX;
      const dy = touch.clientY - state.current.lastTouchY;

      // 即時反映 (補間なし)
      x.set(x.get() + dx);
      y.set(y.get() + dy);

      state.current.lastTouchX = touch.clientX;
      state.current.lastTouchY = touch.clientY;

    } else if (state.current.isPinching && e.touches.length === 2) {
      // --- 2本指: ピンチ実行 ---
      const t1 = e.touches[0];
      const t2 = e.touches[1];
      
      const currentDist = getDistance(t1, t2);
      const zoomFactor = currentDist / state.current.startDist;
      
      // 新しいスケールを計算 (制限付き)
      const newScale = Math.min(Math.max(state.current.startScale * zoomFactor, MIN_ZOOM), MAX_ZOOM);
      
      // --- 中点ズーム計算 ---
      // 画面上のピンチ中心は、拡大前後で同じ位置に見えるべき
      // Formula: P_screen = P_world * Scale + Translate
      // Translate_new = P_screen - (P_screen - Translate_old) * (Scale_new / Scale_old)
      
      const pCx = state.current.startPinchCenter.x;
      const pCy = state.current.startPinchCenter.y;
      
      // コンテナのバウンディングボックスを取得して、座標系を合わせる（必要なら）
      // 今回は e.clientX/Y (Viewport座標) と x, y (CSS transform) の関係で計算
      // ただし、x, y はコンテナ左上からの相対位置として機能する（absolute配置のため）
      // ここでは簡略化のために、初期位置からの差分で計算
      
      // 厳密な座標変換（画面中心基準）
      // コンテナの位置が (0,0) 前提であれば clientX/Y をそのまま使えるが、
      // 実際にはオフセットがある可能性があるため、コンテナのrectを取得
      const rect = containerRef.current?.getBoundingClientRect();
      if (!rect) return;

      const relCx = pCx - rect.left; // コンテナ内の相対座標
      const relCy = pCy - rect.top;

      // ズーム前のワールド座標（Scale=1 の世界での位置）
      const worldX = (relCx - state.current.startTx) / state.current.startScale;
      const worldY = (relCy - state.current.startTy) / state.current.startScale;

      // ズーム後の新しい Translate
      const newTx = relCx - (worldX * newScale);
      const newTy = relCy - (worldY * newScale);

      // 同時反映
      scale.set(newScale);
      x.set(newTx);
      y.set(newTy);
      
      // 現在の2本指中心が移動していたら、パンも追従させる（2本指ドラッグのサポート）
      const currentCenter = getCenter(t1, t2);
      const moveDx = currentCenter.x - state.current.startPinchCenter.x;
      const moveDy = currentCenter.y - state.current.startPinchCenter.y;
      
      // 中心移動分を加算
      x.set(newTx + moveDx);
      y.set(newTy + moveDy);
    }
  };

  const handleTouchEnd = () => {
    state.current.isDragging = false;
    state.current.isPinching = false;
  };

  // ------------------------------------------------------------------
  // Mouse / Wheel Handlers (Desktop / Trackpad)
  // スマホのロジックとは完全に分離する
  // ------------------------------------------------------------------

  const handleWheel = (e: React.WheelEvent) => {
    e.preventDefault();
    e.stopPropagation();

    // トラックパッドのピンチ操作は e.ctrlKey が true になることが多い
    if (e.ctrlKey) {
      // --- Zoom ---
      const rect = containerRef.current?.getBoundingClientRect();
      if (!rect) return;

      const ZOOM_SPEED = 0.01;
      const delta = -e.deltaY * ZOOM_SPEED;
      const currentScale = scale.get();
      const newScale = Math.min(Math.max(currentScale + delta, MIN_ZOOM), MAX_ZOOM);

      // マウス位置を中心にズーム
      const relMx = e.clientX - rect.left;
      const relMy = e.clientY - rect.top;

      const worldX = (relMx - x.get()) / currentScale;
      const worldY = (relMy - y.get()) / currentScale;

      const newTx = relMx - (worldX * newScale);
      const newTy = relMy - (worldY * newScale);

      scale.set(newScale);
      x.set(newTx);
      y.set(newTy);
    } else {
      // --- Pan (Wheel) ---
      x.set(x.get() - e.deltaX);
      y.set(y.get() - e.deltaY);
    }
  };

  const handleMouseDown = (e: React.MouseEvent) => {
    state.current.isMouseDn = true;
    state.current.lastTouchX = e.clientX;
    state.current.lastTouchY = e.clientY;
  };

  const handleMouseMove = (e: React.MouseEvent) => {
    if (!state.current.isMouseDn) return;
    e.preventDefault();

    const dx = e.clientX - state.current.lastTouchX;
    const dy = e.clientY - state.current.lastTouchY;

    x.set(x.get() + dx);
    y.set(y.get() + dy);

    state.current.lastTouchX = e.clientX;
    state.current.lastTouchY = e.clientY;
  };

  const handleMouseUp = () => {
    state.current.isMouseDn = false;
  };

  // ------------------------------------------------------------------
  // Global Event Listeners for Safety
  // ------------------------------------------------------------------
  useEffect(() => {
    const el = containerRef.current;
    if (!el) return;

    // Safariのピンチズーム無効化（Webkit特有）
    const preventDefault = (e: Event) => e.preventDefault();
    
    // パッシブイベントリスナーではないことを明示して、preventDefaultを効かせる
    el.addEventListener('gesturestart', preventDefault);
    el.addEventListener('gesturechange', preventDefault);
    el.addEventListener('gestureend', preventDefault);

    return () => {
      el.removeEventListener('gesturestart', preventDefault);
      el.removeEventListener('gesturechange', preventDefault);
      el.removeEventListener('gestureend', preventDefault);
    };
  }, []);

  const isCurrentFloorInRoute = route?.currentFloor === currentFloor;

  return (
    <div 
      ref={containerRef} 
      className="absolute inset-0 bg-[#e5e5f7] overflow-hidden select-none"
      style={{ 
        touchAction: 'none', // ブラウザ標準のパン・ズームを無効化
        cursor: state.current.isDragging ? 'grabbing' : 'grab',
        backgroundImage: 'radial-gradient(var(--primary-weak) 1px, transparent 1px)',
        backgroundSize: '20px 20px'
      }}
      // Desktop Events
      onWheel={handleWheel}
      onMouseDown={handleMouseDown}
      onMouseMove={handleMouseMove}
      onMouseUp={handleMouseUp}
      onMouseLeave={handleMouseUp}
      // Mobile Events (Native-like)
      onTouchStart={handleTouchStart}
      onTouchMove={handleTouchMove}
      onTouchEnd={handleTouchEnd}
      onTouchCancel={handleTouchEnd}
    >
      <motion.div
        ref={contentRef}
        className="relative w-full h-full origin-top-left will-change-transform"
        style={{ x, y, scale }}
      >
        {/* Map SVG Content Layer */}
        <div className="absolute inset-0 pointer-events-none">
          {/* Base Grid / Blueprint */}
          <svg className="w-full h-full opacity-30">
            <defs>
              <pattern id="grid-large" width="100" height="100" patternUnits="userSpaceOnUse">
                <path d="M 100 0 L 0 0 0 100" fill="none" stroke="currentColor" strokeWidth="1" />
              </pattern>
            </defs>
            <rect width="100%" height="100%" fill="url(#grid-large)" style={{ color: 'var(--primary)' }} />
          </svg>
          
          {/* Floor Label */}
          <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 opacity-10">
            <span className="text-[200px] font-bold text-[--primary]">{currentFloor}</span>
          </div>

          {/* Route Layer */}
          {route && isCurrentFloorInRoute && (
            <svg className="absolute inset-0 w-full h-full">
              <motion.line
                x1={`${route.from.x}%`}
                y1={`${route.from.y}%`}
                x2={`${route.to.x}%`}
                y2={`${route.to.y}%`}
                stroke="var(--primary)"
                strokeWidth="4"
                strokeLinecap="round"
                strokeDasharray="12 6"
                initial={{ pathLength: 0 }}
                animate={{ pathLength: 1 }}
                transition={{ duration: 0.8, ease: "easeOut" }}
              />
              <circle cx={`${route.from.x}%`} cy={`${route.from.y}%`} r="6" fill="var(--primary)" />
              <circle cx={`${route.to.x}%`} cy={`${route.to.y}%`} r="6" fill="var(--destructive)" />
            </svg>
          )}
        </div>

        {/* Interactive Markers Layer */}
        {spots
          .filter(spot => spot.floor === currentFloor)
          .map(spot => (
            <div
              key={spot.id}
              className="absolute"
              style={{
                left: `${spot.x}%`,
                top: `${spot.y}%`,
                transform: 'translate(-50%, -50%)', 
                zIndex: selectedSpot?.id === spot.id ? 50 : 10,
              }}
            >
              <motion.div style={{ scale: markerScale }}>
                <MapMarker
                  spot={spot}
                  isSelected={selectedSpot?.id === spot.id}
                  onClick={() => onSpotClick?.(spot)}
                />
              </motion.div>
            </div>
          ))}
      </motion.div>
    </div>
  );
}
