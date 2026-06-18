import { StyleSheet, Text, View } from 'react-native';
import Svg, { Path, Rect } from 'react-native-svg';
import { colors, radii, spacing } from '../../theme/tokens';
import type { MapSpot } from '../../types/navigation';
import { MapMarker } from './MapMarker';

type MapCanvasProps = {
  currentFloor: string;
  spots: MapSpot[];
  selectedSpot?: MapSpot;
  onSpotPress: (spot: MapSpot) => void;
};

const areaLabels = [
  { label: '受付', left: '22%', top: '47%' },
  { label: '講義室', left: '48%', top: '27%' },
  { label: '実習', left: '67%', top: '58%' },
  { label: '相談', left: '37%', top: '70%' },
] as const;

export function MapCanvas({ currentFloor, spots, selectedSpot, onSpotPress }: MapCanvasProps) {
  const floorSpots = spots.filter((spot) => spot.floor === currentFloor);

  return (
    <View style={styles.canvas}>
      <Svg style={StyleSheet.absoluteFill} width="100%" height="100%" viewBox="0 0 100 100" preserveAspectRatio="none">
        <Rect x="0" y="0" width="100" height="100" fill={colors.mapBackground} />
        <Path d="M7 80 C18 88 31 86 42 81 C55 75 69 76 91 84" stroke={colors.sky} strokeWidth="5" fill="none" strokeLinecap="round" opacity="0.35" />
        <Rect x="7" y="12" width="86" height="76" rx="5" fill={colors.mapBuilding} opacity="0.72" />
        <Rect x="12" y="18" width="76" height="63" rx="4" fill={colors.mapPath} />
        <Path d="M24 18 V80" stroke={colors.mapBuilding} strokeWidth="2.2" strokeLinecap="round" />
        <Path d="M24 52 H79" stroke={colors.mapBuilding} strokeWidth="2.2" strokeLinecap="round" />
        <Path d="M38 18 V52" stroke={colors.mapBuilding} strokeWidth="1.2" strokeLinecap="round" opacity="0.7" />
        <Path d="M62 52 V80" stroke={colors.mapBuilding} strokeWidth="1.2" strokeLinecap="round" opacity="0.7" />
        <Rect x="35" y="20" width="34" height="20" rx="3" fill={colors.mapRoom} stroke={colors.border} strokeWidth="0.6" />
        <Rect x="14" y="47" width="20" height="17" rx="3" fill={colors.mapRoom} stroke={colors.border} strokeWidth="0.6" />
        <Rect x="58" y="57" width="28" height="20" rx="3" fill={colors.mapRoom} stroke={colors.border} strokeWidth="0.6" />
        <Rect x="35" y="66" width="22" height="13" rx="3" fill={colors.mapRoom} stroke={colors.border} strokeWidth="0.6" />
        <Rect x="77" y="34" width="10" height="12" rx="2" fill={colors.mapRoom} stroke={colors.border} strokeWidth="0.6" />
      </Svg>

      <View pointerEvents="none" style={styles.mapBadge}>
        <Text style={styles.mapBadgeText}>簡易マップ</Text>
      </View>

      <View pointerEvents="none" style={styles.floorBadge}>
        <Text style={styles.floorText}>{currentFloor}</Text>
      </View>

      {areaLabels.map((item) => (
        <View key={item.label} pointerEvents="none" style={[styles.areaLabel, { left: item.left, top: item.top }]}>
          <Text style={styles.areaLabelText}>{item.label}</Text>
        </View>
      ))}

      {floorSpots.map((spot) => (
        <MapMarker key={spot.id} spot={spot} selected={selectedSpot?.id === spot.id} onPress={() => onSpotPress(spot)} />
      ))}
    </View>
  );
}

const styles = StyleSheet.create({
  canvas: {
    backgroundColor: colors.mapBackground,
    flex: 1,
    overflow: 'hidden',
    position: 'relative',
  },
  mapBadge: {
    backgroundColor: colors.floatingSurface,
    borderColor: colors.border,
    borderRadius: radii.pill,
    borderWidth: StyleSheet.hairlineWidth,
    left: spacing.lg,
    paddingHorizontal: spacing.md,
    paddingVertical: 6,
    position: 'absolute',
    top: 82,
  },
  mapBadgeText: {
    color: colors.mapLabel,
    fontSize: 11,
    fontWeight: '800',
  },
  floorBadge: {
    alignItems: 'center',
    backgroundColor: colors.floatingSurface,
    borderColor: colors.border,
    borderRadius: radii.pill,
    borderWidth: StyleSheet.hairlineWidth,
    height: 34,
    justifyContent: 'center',
    position: 'absolute',
    right: spacing.lg,
    top: 82,
    width: 46,
  },
  floorText: {
    color: colors.primary,
    fontSize: 12,
    fontWeight: '900',
  },
  areaLabel: {
    backgroundColor: colors.floatingSurface,
    borderColor: colors.border,
    borderRadius: radii.pill,
    borderWidth: StyleSheet.hairlineWidth,
    marginLeft: -24,
    paddingHorizontal: spacing.sm,
    paddingVertical: 3,
    position: 'absolute',
  },
  areaLabelText: {
    color: colors.mapLabel,
    fontSize: 10,
    fontWeight: '800',
  },
});
