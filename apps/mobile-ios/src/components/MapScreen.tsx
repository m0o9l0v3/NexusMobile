import { useEffect, useMemo, useState } from 'react';
import { Pressable, SafeAreaView, StyleSheet, Text, View } from 'react-native';
import { createNavigationApiClient, type FloorMap, type Spot } from '@nexus/shared';
import { BottomNav } from './BottomNav';
import { AppIcon } from './icons/AppIcon';
import { colors, radii, shadows, spacing, typography } from '../theme/tokens';
import type { CongestionLevel, MapSpot, RouteInfo } from '../types/navigation';
import { BottomSheet } from './map/BottomSheet';
import { CongestionFilter } from './map/CongestionFilter';
import { fallbackFloors, fallbackRoute, fallbackSpots } from './map/mockData';
import { FloorSwitch } from './map/FloorSwitch';
import { MapCanvas } from './map/MapCanvas';
import { MapSearchOverlay } from './map/MapSearchOverlay';

type MapScreenProps = {
  focusSpotName?: string;
};

const api = createNavigationApiClient({
  baseUrl: process.env.EXPO_PUBLIC_API_BASE_URL ?? 'http://localhost:5001',
});

const allCongestionLevels: CongestionLevel[] = ['empty', 'normal', 'busy', 'full'];

const mapApiSpot = (spot: Spot): MapSpot => ({
  ...spot,
  x: spot.x > 100 ? spot.x / 10 : spot.x,
  y: spot.y > 100 ? spot.y / 10 : spot.y,
  congestion: 'normal',
  relatedEvents: 0,
});

export function MapScreen({ focusSpotName }: MapScreenProps) {
  const [spots, setSpots] = useState<MapSpot[]>(fallbackSpots);
  const [floors, setFloors] = useState<FloorMap[]>(fallbackFloors);
  const [currentFloor, setCurrentFloor] = useState('1F');
  const [selectedSpot, setSelectedSpot] = useState<MapSpot | undefined>();
  const [isBottomSheetOpen, setIsBottomSheetOpen] = useState(false);
  const [bottomSheetMode, setBottomSheetMode] = useState<'spot' | 'route' | null>(null);
  const [routeInfo, setRouteInfo] = useState<RouteInfo | undefined>();
  const [isSearching, setIsSearching] = useState(false);
  const [isFilterOpen, setIsFilterOpen] = useState(false);
  const [origin, setOrigin] = useState<MapSpot | undefined>();
  const [destination, setDestination] = useState<MapSpot | undefined>();
  const [selectedCongestionLevels, setSelectedCongestionLevels] = useState<CongestionLevel[]>(allCongestionLevels);

  useEffect(() => {
    api.getSpots()
      .then((data) => setSpots(data.map(mapApiSpot)))
      .catch(() => setSpots(fallbackSpots));

    api.getFloors()
      .then(setFloors)
      .catch(() => setFloors(fallbackFloors));
  }, []);

  useEffect(() => {
    if (!focusSpotName) return;
    const spot = spots.find((item) => item.name === focusSpotName);
    if (!spot) return;

    setCurrentFloor(spot.floor);
    setSelectedSpot(spot);
    setBottomSheetMode('spot');
    setIsBottomSheetOpen(true);
  }, [focusSpotName, spots]);

  const floorNames = useMemo(() => floors.map((floor) => floor.name), [floors]);
  const filteredSpots = useMemo(
    () => spots.filter((spot) => selectedCongestionLevels.includes(spot.congestion)),
    [selectedCongestionLevels, spots],
  );

  const route = useMemo(() => {
    if (!origin || !destination) {
      return undefined;
    }

    return {
      from: origin,
      to: destination,
      currentFloor,
    };
  }, [currentFloor, destination, origin]);

  const handleSpotPress = (spot: MapSpot) => {
    setSelectedSpot(spot);
    setBottomSheetMode('spot');
    setIsBottomSheetOpen(true);
  };

  const handleLevelToggle = (level: CongestionLevel) => {
    setSelectedCongestionLevels((current) => {
      if (current.includes(level)) {
        return current.length === 1 ? current : current.filter((item) => item !== level);
      }

      return [...current, level];
    });
  };

  const handleSetOrigin = (spot: MapSpot) => {
    setOrigin(spot);
    setCurrentFloor(spot.floor);
    if (destination) {
      setRouteInfo(fallbackRoute);
      setBottomSheetMode('route');
    }
  };

  const handleSetDestination = (spot: MapSpot) => {
    setDestination(spot);
    setCurrentFloor(spot.floor);
    if (origin) {
      setRouteInfo(fallbackRoute);
      setBottomSheetMode('route');
    }
  };

  return (
    <View style={styles.root}>
      <SafeAreaView style={styles.safeArea}>
        <MapCanvas
          currentFloor={currentFloor}
          spots={filteredSpots}
          selectedSpot={selectedSpot}
          route={route}
          onSpotPress={handleSpotPress}
        />

        <View style={styles.topBar}>
          <Pressable onPress={() => setIsSearching(true)} style={styles.searchButton}>
            <View style={styles.searchIconBox}>
              <AppIcon name="search" size={18} color={colors.primary} />
            </View>
            <Text style={styles.searchText}>ここで検索</Text>
          </Pressable>
          <FloorSwitch floors={floorNames} currentFloor={currentFloor} onFloorChange={setCurrentFloor} />
        </View>

        <View style={styles.filterWrap}>
          <Pressable onPress={() => setIsFilterOpen((value) => !value)} style={styles.filterButton}>
            <AppIcon name="filter" size={20} color={isFilterOpen ? colors.primary : colors.text} />
          </Pressable>
          <CongestionFilter
            isOpen={isFilterOpen}
            selectedLevels={selectedCongestionLevels}
            onLevelToggle={handleLevelToggle}
            onClear={() => setSelectedCongestionLevels(allCongestionLevels)}
          />
        </View>

        {origin || destination ? (
          <View style={styles.routeSummary}>
            <Text style={styles.routeText}>From: {origin?.name ?? '-'}</Text>
            <Text style={styles.routeText}>To: {destination?.name ?? '-'}</Text>
          </View>
        ) : null}

        <BottomSheet
          isOpen={isBottomSheetOpen}
          mode={bottomSheetMode}
          spot={selectedSpot}
          routeInfo={routeInfo}
          onClose={() => setIsBottomSheetOpen(false)}
          onSetOrigin={handleSetOrigin}
          onSetDestination={handleSetDestination}
        />

        <MapSearchOverlay
          isOpen={isSearching}
          spots={spots}
          onClose={() => setIsSearching(false)}
          onSelectSpot={(spot) => {
            setCurrentFloor(spot.floor);
            handleSpotPress(spot);
          }}
        />
      </SafeAreaView>
      <BottomNav />
    </View>
  );
}

const styles = StyleSheet.create({
  root: {
    backgroundColor: colors.sky0,
    flex: 1,
  },
  safeArea: {
    flex: 1,
  },
  topBar: {
    gap: spacing.md,
    left: 0,
    padding: spacing.lg,
    position: 'absolute',
    right: 0,
    top: 0,
    zIndex: 20,
  },
  searchButton: {
    alignItems: 'center',
    backgroundColor: colors.surface,
    borderRadius: radii.pill,
    flexDirection: 'row',
    gap: spacing.md,
    paddingHorizontal: spacing.lg,
    paddingVertical: spacing.md,
    ...shadows.level2,
  },
  searchIconBox: {
    alignItems: 'center',
    backgroundColor: colors.muted,
    borderRadius: radii.md,
    height: 32,
    justifyContent: 'center',
    width: 32,
  },
  searchText: {
    ...typography.body,
    flex: 1,
  },
  filterWrap: {
    position: 'absolute',
    right: spacing.lg,
    top: 130,
    zIndex: 30,
  },
  filterButton: {
    alignItems: 'center',
    backgroundColor: colors.surface,
    borderRadius: radii.pill,
    height: 48,
    justifyContent: 'center',
    width: 48,
    ...shadows.level2,
  },
  routeSummary: {
    backgroundColor: colors.surface,
    borderRadius: radii.lg,
    bottom: 104,
    gap: 3,
    left: spacing.lg,
    padding: spacing.md,
    position: 'absolute',
    right: spacing.lg,
    ...shadows.level2,
  },
  routeText: {
    color: colors.text,
    fontSize: 12,
    fontWeight: '600',
  },
});
