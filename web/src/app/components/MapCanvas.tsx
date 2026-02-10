import { useEffect, useRef } from "react";
import { motion } from "motion/react";
import { MapMarker } from "@/app/components/MapMarker";
import { attachMapInteractionsToElement } from "@/map/map-interactions-dom"; // ←後述

type Spot = {
  id: string;
  name: string;
  floor: string;
  x: number;
  y: number;
  congestion: "empty" | "normal" | "busy" | "full";
  category: string;
  isDestination?: boolean;
  isOrigin?: boolean;
};

type Route = {
  from: Spot;
  to: Spot;
  currentFloor: string;
};

type MapCanvasProps = {
  currentFloor: string;
  spots: Spot[];
  selectedSpot?: Spot;
  route?: Route;
  onSpotClick?: (spot: Spot) => void;
};

export function MapCanvas({
  currentFloor,
  spots,
  selectedSpot,
  route,
  onSpotClick,
}: MapCanvasProps) {
  const isCurrentFloorInRoute = route?.currentFloor === currentFloor;

  const viewportRef = useRef<HTMLDivElement | null>(null);
  const contentRef = useRef<HTMLDivElement | null>(null);

  useEffect(() => {
    const viewport = viewportRef.current;
    const content = contentRef.current;
    if (!viewport || !content) return;

    // StrictMode等で二重登録を防ぐ
    if ((viewport as any).__mapGesturesAttached) return;
    (viewport as any).__mapGesturesAttached = true;

    attachMapInteractionsToElement(viewport, content);
  }, []);

  return (
    <div
      ref={viewportRef}
      className="absolute inset-0 bg-gradient-to-b from-[--sky-1] to-[--sky-0] overflow-hidden"
      style={{ touchAction: "none" }}
    >
      {/* ★ここから下が「動く対象」 */}
      <div ref={contentRef} className="absolute inset-0">
        {/* Grid placeholder */}
        <svg className="w-full h-full opacity-20">
          <defs>
            <pattern
              id="grid"
              width="40"
              height="40"
              patternUnits="userSpaceOnUse"
            >
              <path
                d="M 40 0 L 0 0 0 40"
                fill="none"
                stroke="currentColor"
                strokeWidth="0.5"
                className="text-[--text]"
              />
            </pattern>
          </defs>
          <rect width="100%" height="100%" fill="url(#grid)" />
        </svg>

        {/* Floor label（固定にしたいなら content の外へ移動） */}
        <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 pointer-events-none">
          <div className="text-6xl font-light opacity-10 text-[--text] select-none">
            {currentFloor}
          </div>
          <div className="text-sm text-center opacity-30 text-[--muted-foreground] mt-2">
            FLOOR MAP (Placeholder)
          </div>
        </div>

        {/* Route line */}
        {route && isCurrentFloorInRoute && (
          <motion.svg
            className="absolute inset-0 w-full h-full pointer-events-none"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ duration: 0.3 }}
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
              transition={{ duration: 0.6, ease: "easeOut" }}
            />
          </motion.svg>
        )}

        {/* Spot markers */}
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
      </div>
    </div>
  );
}
