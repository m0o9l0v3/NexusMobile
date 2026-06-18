import { Pressable, StyleSheet, Text, View } from 'react-native';
import { colors, radii, shadows } from '../../theme/tokens';
import type { MapSpot } from '../../types/navigation';

type MapMarkerProps = {
  spot: MapSpot;
  selected: boolean;
  onPress: () => void;
};

const congestionColor = {
  empty: colors.empty,
  normal: colors.normal,
  busy: colors.busy,
  full: colors.full,
};

export function MapMarker({ spot, selected, onPress }: MapMarkerProps) {
  const markerColor = spot.kind === 'current' ? colors.accent : spot.kind === 'support' ? colors.primary : congestionColor[spot.congestion];

  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={spot.name}
      onPress={onPress}
      style={[
        styles.marker,
        { left: `${spot.x}%`, top: `${spot.y}%`, backgroundColor: markerColor },
        spot.kind === 'current' && styles.current,
        selected && spot.kind !== 'current' && styles.destination,
        selected && styles.selected,
      ]}
    >
      {selected ? (
        <View style={styles.labelWrap}>
          <Text style={styles.label} numberOfLines={1}>{spot.name}</Text>
        </View>
      ) : null}
    </Pressable>
  );
}

const styles = StyleSheet.create({
  marker: {
    borderColor: colors.surface,
    borderRadius: radii.pill,
    borderWidth: 2,
    height: 18,
    marginLeft: -9,
    marginTop: -9,
    position: 'absolute',
    width: 18,
    ...shadows.level2,
  },
  current: {
    borderColor: colors.sky,
    borderWidth: 4,
    height: 24,
    marginLeft: -12,
    marginTop: -12,
    width: 24,
  },
  destination: {
    borderColor: colors.surface,
    borderWidth: 3,
  },
  selected: {
    height: 28,
    marginLeft: -14,
    marginTop: -14,
    width: 28,
  },
  labelWrap: {
    backgroundColor: colors.floatingSurface,
    borderColor: colors.border,
    borderRadius: radii.pill,
    borderWidth: StyleSheet.hairlineWidth,
    bottom: 32,
    left: -48,
    paddingHorizontal: 10,
    paddingVertical: 4,
    position: 'absolute',
    width: 126,
    ...shadows.level1,
  },
  label: {
    color: colors.text,
    fontSize: 11,
    fontWeight: '700',
    textAlign: 'center',
  },
});
