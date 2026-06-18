import { router } from 'expo-router';
import { useEffect, useMemo, useState } from 'react';
import { Pressable, SafeAreaView, StyleSheet, Text, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { createNavigationApiClient, type Spot } from '@nexus/shared';
import { getFeaturedEvent, getSpotNameForEvent, openCampusEvents } from '../data/openCampus';
import { colors, radii, shadows, spacing } from '../theme/tokens';
import type { CampusEvent } from '../types/events';
import type { MapSpot } from '../types/navigation';
import { BottomNav } from './BottomNav';
import { AppIcon } from './icons/AppIcon';
import { BottomSheet } from './map/BottomSheet';
import { fallbackSpots } from './map/mockData';
import { MapCanvas } from './map/MapCanvas';
import { MapSearchOverlay } from './map/MapSearchOverlay';

type MapScreenProps = {
  focusSpotName?: string;
};

const api = createNavigationApiClient({
  baseUrl: process.env.EXPO_PUBLIC_API_BASE_URL ?? 'http://localhost:5001',
});

const supportNames = ['受付', '相談会場', '出入口'];

const getSpotKind = (spot: Spot): MapSpot['kind'] => {
  if (spot.name.includes('現在地')) return 'current';
  if (supportNames.some((name) => spot.name.includes(name))) return 'support';
  return 'place';
};

const getFallbackProfile = (spot: Spot): Partial<MapSpot> => {
  return fallbackSpots.find((item) => item.name === spot.name) ?? {};
};

const mapApiSpot = (spot: Spot): MapSpot => {
  const profile = getFallbackProfile(spot);
  return {
    ...spot,
    x: spot.x > 100 ? spot.x / 10 : spot.x,
    y: spot.y > 100 ? spot.y / 10 : spot.y,
    congestion: 'normal',
    kind: getSpotKind(spot),
    relatedEventId: profile.relatedEventId,
    relatedEvents: profile.relatedEvents ?? 0,
    travelEstimate: profile.travelEstimate,
  };
};

const findSpotByName = (spots: MapSpot[], name: string | undefined): MapSpot | undefined => {
  if (!name) return undefined;
  return spots.find((spot) => spot.name === name || spot.name.includes(name) || name.includes(spot.name));
};

export function MapScreen({ focusSpotName }: MapScreenProps) {
  const insets = useSafeAreaInsets();
  const [spots, setSpots] = useState<MapSpot[]>(fallbackSpots);
  const [currentFloor, setCurrentFloor] = useState('1F');
  const [selectedSpot, setSelectedSpot] = useState<MapSpot | undefined>();
  const [isSearching, setIsSearching] = useState(false);

  const featuredEvent = useMemo(() => getFeaturedEvent(openCampusEvents), []);
  const receptionSpot = useMemo(() => findSpotByName(spots, '受付') ?? fallbackSpots[0], [spots]);
  const currentLocationSpot = useMemo(() => spots.find((spot) => spot.kind === 'current') ?? fallbackSpots.find((spot) => spot.kind === 'current'), [spots]);
  const relatedEvent = useMemo<CampusEvent | undefined>(() => {
    if (!selectedSpot?.relatedEventId) return featuredEvent;
    return openCampusEvents.find((event) => event.id === selectedSpot.relatedEventId) ?? featuredEvent;
  }, [featuredEvent, selectedSpot?.relatedEventId]);

  useEffect(() => {
    api.getSpots()
      .then((data) => setSpots(data.map(mapApiSpot)))
      .catch(() => setSpots(fallbackSpots));
  }, []);

  useEffect(() => {
    const targetName = focusSpotName ?? (featuredEvent ? getSpotNameForEvent(featuredEvent) : undefined);
    const targetSpot = findSpotByName(spots, targetName) ?? findSpotByName(spots, '受付');
    if (!targetSpot) return;

    setCurrentFloor(targetSpot.floor);
    setSelectedSpot(targetSpot);
  }, [featuredEvent, focusSpotName, spots]);

  const handleSpotPress = (spot: MapSpot) => {
    setCurrentFloor(spot.floor);
    setSelectedSpot(spot);
  };

  const handleReturnToReception = () => {
    handleSpotPress(receptionSpot);
  };

  const handleShowCurrentLocation = () => {
    if (!currentLocationSpot) return;
    handleSpotPress(currentLocationSpot);
  };

  return (
    <View style={styles.root}>
      <SafeAreaView style={styles.safeArea}>
        <MapCanvas currentFloor={currentFloor} spots={spots} selectedSpot={selectedSpot} onSpotPress={handleSpotPress} />

        <View style={[styles.searchWrap, { top: insets.top + 18 }]}>
          <Pressable onPress={() => setIsSearching(true)} style={({ pressed }) => [styles.searchPill, pressed && styles.pressed]}>
            <AppIcon name="search" size={18} color={colors.accent} />
            <Text style={styles.searchText}>場所・教室・イベントを検索</Text>
          </Pressable>
        </View>

        <View style={styles.actionStack}>
          <Pressable
            accessibilityLabel="現在地を表示"
            accessibilityRole="button"
            onPress={handleShowCurrentLocation}
            style={({ pressed }) => [styles.roundButton, pressed && styles.pressed]}
          >
            <AppIcon name="navigation" size={20} color={colors.accent} />
          </Pressable>
          <Pressable
            accessibilityLabel="受付へ戻る"
            accessibilityRole="button"
            onPress={handleReturnToReception}
            style={({ pressed }) => [styles.roundButton, pressed && styles.pressed]}
          >
            <AppIcon name="shield" size={20} color={colors.primary} />
          </Pressable>
        </View>

        <BottomSheet
          spot={selectedSpot}
          event={relatedEvent}
          onGuide={() => selectedSpot && handleSpotPress(selectedSpot)}
          onShowDetail={() => {
            if (!relatedEvent) return;
            router.push({ pathname: '/events', params: { eventId: relatedEvent.id } });
          }}
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
    backgroundColor: colors.mapBackground,
    flex: 1,
  },
  safeArea: {
    flex: 1,
  },
  searchWrap: {
    left: 24,
    position: 'absolute',
    right: 24,
    zIndex: 45,
  },
  searchPill: {
    alignItems: 'center',
    backgroundColor: colors.floatingSurface,
    borderColor: colors.border,
    borderRadius: 29,
    borderWidth: StyleSheet.hairlineWidth,
    flexDirection: 'row',
    gap: 14,
    height: 58,
    paddingHorizontal: 22,
    ...shadows.level2,
  },
  searchText: {
    color: colors.subtext,
    flex: 1,
    fontSize: 15,
    fontWeight: '700',
    lineHeight: 21,
  },
  actionStack: {
    bottom: 284,
    gap: spacing.sm,
    position: 'absolute',
    right: spacing.lg,
    zIndex: 30,
  },
  roundButton: {
    alignItems: 'center',
    backgroundColor: colors.floatingSurface,
    borderColor: colors.border,
    borderRadius: radii.pill,
    borderWidth: StyleSheet.hairlineWidth,
    height: 48,
    justifyContent: 'center',
    width: 48,
    ...shadows.level1,
  },
  pressed: {
    opacity: 0.78,
  },
});
