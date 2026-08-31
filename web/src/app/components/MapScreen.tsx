import { useEffect, useRef, useState } from 'react';
import { toast } from 'sonner';
import { MapCanvas } from '@/app/components/MapCanvas';
import { FloorSwitch } from '@/app/components/FloorSwitch';
import { BottomSheet } from '@/app/components/BottomSheet';
import { MapSearchOverlay } from '@/app/components/MapSearchOverlay';
import aviationLogo from '@/assets/map/aviation-logo.png';
import currentLocationIcon from '@/assets/map/current-location-active.svg';
import micIcon from '@/assets/map/mic.svg';
import searchIcon from '@/assets/map/search.svg';

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
  supportPickMode = false,
  onSupportPickSpot,
  focusSpotName,
}: MapScreenProps) {
  const [currentFloor, setCurrentFloor] = useState('1F');
  const [isSearching, setIsSearching] = useState(false);
  const [selectedSpot, setSelectedSpot] = useState<Spot>();
  const [isBottomSheetOpen, setIsBottomSheetOpen] = useState(false);
  const [mapResetKey, setMapResetKey] = useState(0);
  const searchTriggerRef = useRef<HTMLButtonElement>(null);

  const showContextualMarkers = supportPickMode || Boolean(focusSpotName) || Boolean(selectedSpot);

  useEffect(() => {
    if (!focusSpotName) return;
    const spot = spots.find((candidate) => candidate.name === focusSpotName);
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

    setIsBottomSheetOpen(true);
    onSpotClick?.(spot);
  };

  const closeSearch = () => {
    setIsSearching(false);
    window.requestAnimationFrame(() => searchTriggerRef.current?.focus());
  };

  const resetToCurrentLocation = () => {
    if (typeof navigator === 'undefined' || !navigator.geolocation) {
      setMapResetKey((key) => key + 1);
      toast('この端末では位置情報を利用できません');
      return;
    }

    navigator.geolocation.getCurrentPosition(
      () => setMapResetKey((key) => key + 1),
      () => toast('位置情報を取得できませんでした'),
      { enableHighAccuracy: true, timeout: 5000 },
    );
  };

  return (
    <div className="relative h-full overflow-hidden bg-white">
      <div
        className={isSearching ? 'pointer-events-none h-full' : 'h-full'}
        aria-hidden={isSearching}
      >
        <MapCanvas
          key={mapResetKey}
          currentFloor={currentFloor}
          spots={spots}
          selectedSpot={selectedSpot}
          showMarkers={showContextualMarkers}
          onSpotClick={handleSpotClick}
        />

        <div
          className="absolute left-0 right-0 z-20 flex justify-center"
          style={{ top: 'calc(env(safe-area-inset-top, 0px) + 26px)' }}
        >
          <button
            ref={searchTriggerRef}
            type="button"
            onClick={() => setIsSearching(true)}
            className="flex h-[54px] w-[calc(100%_-_13px)] max-w-[380px] items-center gap-[3px] rounded-[27px] bg-white text-left"
            style={{ boxShadow: '0 2px 4px rgba(0, 0, 0, 0.18)' }}
            aria-label="校内マップを検索"
          >
            <span className="flex h-[54px] w-[55px] shrink-0 items-center justify-center">
              <img src={aviationLogo} alt="日本航空学園" className="h-[29px] w-[55px] object-contain" />
            </span>

            <span className="flex h-[41px] min-w-0 flex-1 items-center gap-3 rounded-[20.5px] bg-[#f2f2f2] pl-[14px] pr-3">
              <img src={searchIcon} alt="" className="h-[18px] w-[18px] shrink-0" />
              <span
                className="min-w-0 flex-1 truncate text-[17px] font-semibold leading-[22px] text-[#797979]"
                style={{
                  fontFamily: '-apple-system, BlinkMacSystemFont, "Noto Sans JP", "Inter", sans-serif',
                }}
              >
                校内マップ
              </span>
              <img src={micIcon} alt="" className="h-6 w-6 shrink-0" />
            </span>
          </button>
        </div>

        {supportPickMode && (
          <div
            className="absolute left-4 right-4 z-30"
            style={{ top: 'calc(env(safe-area-inset-top, 0px) + 92px)' }}
          >
            <div
              className="rounded-2xl border px-4 py-2.5"
              style={{
                backgroundColor: 'rgba(255, 255, 255, 0.94)',
                borderColor: 'var(--outline)',
                boxShadow: 'var(--elev-2)',
              }}
            >
              <p className="text-xs font-medium text-[--text]">展示場所をタップしてください</p>
              <p className="text-[11px] text-[--muted-foreground]">選択した場所をサポートへ渡します</p>
            </div>
            <div className="mt-3 flex justify-center">
              <FloorSwitch floors={floors} currentFloor={currentFloor} onFloorChange={setCurrentFloor} />
            </div>
          </div>
        )}

        <button
          type="button"
          onClick={resetToCurrentLocation}
          className="absolute right-4 z-20 flex h-[45px] w-[45px] items-center justify-center rounded-full border border-white/80 bg-white/90 backdrop-blur-md"
          style={{
            bottom: 'calc(env(safe-area-inset-bottom, 0px) + 155px)',
            boxShadow: '0 3px 12px rgba(0, 0, 0, 0.16)',
          }}
          aria-label="現在地へ戻る"
        >
          <img src={currentLocationIcon} alt="" className="h-[21px] w-4" />
        </button>

        <BottomSheet
          isOpen={isBottomSheetOpen}
          mode={selectedSpot ? 'spot' : null}
          spot={selectedSpot}
          onClose={() => setIsBottomSheetOpen(false)}
          onSetDestination={() => undefined}
          onSetOrigin={() => undefined}
        />
      </div>

      <MapSearchOverlay isOpen={isSearching} onClose={closeSearch} />
    </div>
  );
}
