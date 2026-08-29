import { useEffect, useRef } from 'react';
import { motion } from 'motion/react';
import { MapMarker } from '@/app/components/MapMarker';
import { attachMapInteractionsToElement } from '@/map/map-interactions-dom';
import mapBackground from '@/assets/map/map-background.png';

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

type Route = { from: Spot; to: Spot; currentFloor: string };

type MapCanvasProps = {
  currentFloor: string;
  spots: Spot[];
  selectedSpot?: Spot;
  route?: Route;
  showMarkers?: boolean;
  onSpotClick?: (spot: Spot) => void;
};

export function MapCanvas({
  currentFloor,
  spots,
  selectedSpot,
  route,
  showMarkers = false,
  onSpotClick,
}: MapCanvasProps) {
  // Figma準拠の画像レンダラーは暫定実装。将来のMapbox移行はこの
  // コンポーネント内部だけを置き換え、MapScreenのUI契約を維持する。
  const viewportRef = useRef<HTMLDivElement | null>(null);
  const contentRef = useRef<HTMLDivElement | null>(null);
  const isCurrentFloorInRoute = route?.currentFloor === currentFloor;

  useEffect(() => {
    const viewport = viewportRef.current;
    const content = contentRef.current;
    if (viewport && content) attachMapInteractionsToElement(viewport, content);
  }, []);

  return (
    <div
      ref={viewportRef}
      className="absolute inset-0 overflow-hidden bg-[#f5f4ea]"
      style={{ touchAction: 'none' }}
      aria-label="校内マップ"
    >
      <div ref={contentRef} className="absolute inset-0">
        <img
          src={mapBackground}
          alt="恵庭キャンパス周辺の校内マップ"
          className="pointer-events-none absolute max-w-none select-none object-cover"
          style={{ left: '-3.31%', top: '-1.88%', width: '106.36%', height: '106.22%' }}
          draggable={false}
        />

        {showMarkers && route && isCurrentFloorInRoute && (
          <motion.svg
            className="pointer-events-none absolute inset-0 h-full w-full"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ duration: 0.3 }}
            aria-hidden="true"
          >
            <motion.line
              x1={`${route.from.x}%`}
              y1={`${route.from.y}%`}
              x2={`${route.to.x}%`}
              y2={`${route.to.y}%`}
              stroke="var(--primary)"
              strokeWidth="3"
              strokeLinecap="round"
              strokeDasharray="8 4"
              initial={{ pathLength: 0 }}
              animate={{ pathLength: 1 }}
              transition={{ duration: 0.6, ease: 'easeOut' }}
            />
          </motion.svg>
        )}

        {showMarkers && (
          <div className="absolute inset-0">
            {spots
              .filter((spot) => spot.floor === currentFloor)
              .map((spot) => (
                <MapMarker
                  key={spot.id}
                  spot={spot}
                  isSelected={selectedSpot?.id === spot.id}
                  onClick={() => onSpotClick?.(spot)}
                />
              ))}
          </div>
        )}
      </div>
    </div>
  );
}
