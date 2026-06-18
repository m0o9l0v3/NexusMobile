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
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={spot.name}
      onPress={onPress}
      style={[
        styles.marker,
        { left: `${spot.x}%`, top: `${spot.y}%`, backgroundColor: congestionColor[spot.congestion] },
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
    borderWidth: 3,
    height: 22,
    marginLeft: -11,
    marginTop: -11,
    position: 'absolute',
    width: 22,
    ...shadows.level2,
  },
  selected: {
    height: 30,
    marginLeft: -15,
    marginTop: -15,
    width: 30,
  },
  labelWrap: {
    backgroundColor: colors.surface,
    borderRadius: radii.pill,
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
