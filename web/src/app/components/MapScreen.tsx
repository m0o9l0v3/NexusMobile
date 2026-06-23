import { useEffect, useState, useRef } from 'react';
import { Search, Filter } from 'lucide-react';
import { motion } from 'motion/react';
import { MapCanvas } from '@/app/components/MapCanvas';
import { FloorSwitch } from '@/app/components/FloorSwitch';
import { BottomSheet } from '@/app/components/BottomSheet';
import { CongestionFilter } from '@/app/components/CongestionFilter';
import { MapSearchOverlay } from '@/app/components/MapSearchOverlay';

type Spot = {
  id: string;
  name: string;
  floor: string;
  x: number;
  y: number;
  congestion: 'empty' | 'normal' | 'busy' | 'full';
  category: string;
  distance?: number;
  isDestination?: boolean;
  isOrigin?: boolean;
};

type RouteInfo = {
  distance: number;
  duration: number;
  nextFloor?: string;
  nextLandmark?: string;
  steps: Array<{ floor: string; landmark: string }>;
};

type MapScreenProps = {
  spots: Spot[];
  onSpotClick?: (spot: Spot) => void;
  supportPickMode?: boolean;
  onSupportPickSpot?: (spot: Spot) => void;
  focusSpotName?: string;
};

const floors = ['Outdoor', 'B1', '1F', '2F', '3F'];

export function MapScreen({
  spots,
  onSpotClick,
  supportPickMode,
  onSupportPickSpot,
  focusSpotName,
}: MapScreenProps) {
  const [currentFloor, setCurrentFloor] = useState('1F');
  const [zoomLevel, setZoomLevel] = useState(1);
  const [isSearching, setIsSearching] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedSpot, setSelectedSpot] = useState<Spot | undefined>();
  const [isBottomSheetOpen, setIsBottomSheetOpen] = useState(false);
  const [bottomSheetMode, setBottomSheetMode] = useState<'spot' | 'route' | null>(null);
  const [routeInfo, setRouteInfo] = useState<RouteInfo | undefined>();
  const [isFilterOpen, setIsFilterOpen] = useState(false);
  const [selectedCongestionLevels, setSelectedCongestionLevels] = useState<Array<'empty' | 'normal' | 'busy' | 'full'>>([
    'empty',
    'normal',
    'busy',
    'full',
  ]);
  
  const mapRef = useRef<HTMLDivElement>(null);
  const lastTapRef = useRef<number>(0);
  const initialDistanceRef = useRef<number>(0);
  const initialZoomRef = useRef<number>(1);
  
  const filteredSpots = spots.filter(spot =>
    selectedCongestionLevels.includes(spot.congestion)
  );

  useEffect(() => {
    if (!focusSpotName) return;
    const spot = spots.find((s) => s.name === focusSpotName);
    if (!spot) return;
    setCurrentFloor(spot.floor);
    setSelectedSpot(spot);
  }, [focusSpotName, spots]);
  
  const handleSpotClick = (spot: Spot) => {
    setSelectedSpot(spot);
    if (supportPickMode) {
      onSupportPickSpot?.(spot);
      return;
    }
    setBottomSheetMode('spot');
    setIsBottomSheetOpen(true);
    onSpotClick?.(spot);
  };
  
  const handleSearchFocus = () => {
    setIsSearching(true);
  };
  
  const handleSearchClose = () => {
    setIsSearching(false);
  };
  
  const handleSearch = (origin: string, destination: string, waypoints: string[]) => {
    console.log('Search:', { origin, destination, waypoints });
    // TODO: Implement route search logic
    setIsSearching(false);
    setBottomSheetMode('route');
    setIsBottomSheetOpen(true);
  };
  
  // Double tap to zoom
  const handleMapClick = () => {
    const now = Date.now();
    const timeSinceLastTap = now - lastTapRef.current;
    
    if (timeSinceLastTap < 300 && timeSinceLastTap > 0) {
      // Double tap detected
      setZoomLevel(prev => {
        if (prev >= 1.5) return 1; // Zoom out to default
        return Math.min(prev + 0.5, 2); // Zoom in
      });
    }
    
    lastTapRef.current = now;
  };
  
  // Pinch to zoom
  const handleTouchStart = (e: React.TouchEvent) => {
    if (e.touches.length === 2) {
      const touch1 = e.touches[0];
      const touch2 = e.touches[1];
      const distance = Math.hypot(
        touch2.clientX - touch1.clientX,
        touch2.clientY - touch1.clientY
      );
      initialDistanceRef.current = distance;
      initialZoomRef.current = zoomLevel;
    }
  };
  
  const handleTouchMove = (e: React.TouchEvent) => {
    if (e.touches.length === 2) {
      e.preventDefault();
      const touch1 = e.touches[0];
      const touch2 = e.touches[1];
      const distance = Math.hypot(
        touch2.clientX - touch1.clientX,
        touch2.clientY - touch1.clientY
      );
      
      if (initialDistanceRef.current > 0) {
        const scale = distance / initialDistanceRef.current;
        const newZoom = initialZoomRef.current * scale;
        setZoomLevel(Math.max(0.5, Math.min(2, newZoom)));
      }
    }
  };
  
  const handleCongestionLevelToggle = (level: 'empty' | 'normal' | 'busy' | 'full') => {
    setSelectedCongestionLevels(prev => {
      if (prev.includes(level)) {
        if (prev.length === 1) return prev;
        return prev.filter(l => l !== level);
      } else {
        return [...prev, level];
      }
    });
  };
  
  const handleCongestionFilterClear = () => {
    setSelectedCongestionLevels(['empty', 'normal', 'busy', 'full']);
  };
  
  return (
    <div className="h-full relative">
      {supportPickMode && (
        <div
          className="absolute left-0 right-0 z-30 px-4"
          style={{ top: '122px' }}
        >
          <div
            className="px-4 py-2.5 rounded-2xl pointer-events-none"
            style={{
              backgroundColor: 'rgba(255,255,255,0.92)',
              boxShadow: 'var(--elev-2)',
              color: 'var(--text)',
              border: '1px solid var(--outline)',
            }}
          >
            <div className="text-xs font-medium">展示をタップしてください</div>
            <div className="text-[11px]" style={{ color: 'var(--muted-foreground)' }}>
              タップした教室名をサポートに渡します
            </div>
          </div>
        </div>
      )}
      {/* Top bar - Google Maps style */}
      <div className="absolute top-0 left-0 right-0 z-20 p-4 space-y-3">
        {/* Search bar */}
        <button
          onClick={handleSearchFocus}
          className="w-full px-4 py-3 rounded-full flex items-center gap-3 text-left transition-colors"
          style={{
            backgroundColor: 'var(--surface)',
            boxShadow: 'var(--elev-2)',
          }}
        >
          <div 
            className="w-8 h-8 rounded-lg flex items-center justify-center flex-shrink-0"
            style={{ backgroundColor: 'var(--muted)' }}
          >
            <Search size={18} style={{ color: 'var(--primary)' }} />
          </div>
          <span className="text-sm flex-1" style={{ color: 'var(--text)' }}>
            ここで検索
          </span>
        </button>
        
        {/* Floor switcher - centered */}
        <div className="flex justify-center">
          <FloorSwitch
            floors={floors}
            currentFloor={currentFloor}
            onFloorChange={setCurrentFloor}
          />
        </div>
      </div>
      
      {/* Congestion filter - positioned same as Events screen */}
      <div className="absolute right-4 z-20" style={{ top: '130px' }}>
        <motion.button
          onClick={() => setIsFilterOpen(!isFilterOpen)}
          className="w-12 h-12 rounded-full flex items-center justify-center"
          style={{
            backgroundColor: 'var(--surface)',
            boxShadow: 'var(--elev-2)',
          }}
          whileTap={{ scale: 0.9 }}
        >
          <Filter size={20} style={{ color: isFilterOpen ? 'var(--primary)' : 'var(--text)' }} />
        </motion.button>
        
        <CongestionFilter
          isOpen={isFilterOpen}
          selectedLevels={selectedCongestionLevels}
          onToggle={() => setIsFilterOpen(!isFilterOpen)}
          onLevelToggle={handleCongestionLevelToggle}
          onClear={handleCongestionFilterClear}
        />
      </div>
      
      {/* Map canvas */}
      <div 
        ref={mapRef}
        className="absolute inset-0 transition-transform duration-300"
        style={{ 
          transform: `scale(${zoomLevel})`,
          touchAction: 'pan-x pan-y pinch-zoom',
        }}
        onClick={handleMapClick}
        onTouchStart={handleTouchStart}
        onTouchMove={handleTouchMove}
      >
        <MapCanvas
          currentFloor={currentFloor}
          spots={filteredSpots}
          selectedSpot={selectedSpot}
          onSpotClick={handleSpotClick}
        />
      </div>
      
      {/* Bottom sheet */}
      <BottomSheet
        isOpen={isBottomSheetOpen}
        mode={bottomSheetMode}
        spot={selectedSpot}
        routeInfo={routeInfo}
        onClose={() => {
          setIsBottomSheetOpen(false);
          setIsSearching(false);
        }}
        onSetDestination={(spot) => {
          // Handle navigation
        }}
        onSetOrigin={(spot) => {
          // Handle navigation
        }}
      />
      
      {/* Search Overlay */}
        <MapSearchOverlay
          isOpen={isSearching}
          onClose={handleSearchClose}
          onSearch={handleSearch}
        />
    </div>
  );
}
