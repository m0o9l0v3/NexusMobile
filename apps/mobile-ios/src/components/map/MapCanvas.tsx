import { StyleSheet, Text, View } from 'react-native';
import Svg, { Line, Path } from 'react-native-svg';
import { colors } from '../../theme/tokens';
import type { MapSpot } from '../../types/navigation';
import { MapMarker } from './MapMarker';

type MapCanvasProps = {
  currentFloor: string;
  spots: MapSpot[];
  selectedSpot?: MapSpot;
  route?: { from: MapSpot; to: MapSpot; currentFloor: string };
  onSpotPress: (spot: MapSpot) => void;
};

export function MapCanvas({ currentFloor, spots, selectedSpot, route, onSpotPress }: MapCanvasProps) {
  const floorSpots = spots.filter((spot) => spot.floor === currentFloor);
  const showRoute = route?.currentFloor === currentFloor;

  return (
    <View style={styles.canvas}>
      <Svg style={StyleSheet.absoluteFill} width="100%" height="100%" viewBox="0 0 100 100" preserveAspectRatio="none">
        {Array.from({ length: 6 }).map((_, index) => (
          <Line key={`v-${index}`} x1={index * 20} y1="0" x2={index * 20} y2="100" stroke={colors.text} strokeWidth="0.15" opacity="0.18" />
        ))}
        {Array.from({ length: 6 }).map((_, index) => (
          <Line key={`h-${index}`} x1="0" y1={index * 20} x2="100" y2={index * 20} stroke={colors.text} strokeWidth="0.15" opacity="0.18" />
        ))}
        {showRoute && route ? (
          <Path
            d={`M${route.from.x} ${route.from.y} Q50 45 ${route.to.x} ${route.to.y}`}
            stroke={colors.primary}
            strokeWidth="1"
            fill="none"
            strokeDasharray="2 1"
            strokeLinecap="round"
          />
        ) : null}
      </Svg>

      <View pointerEvents="none" style={styles.floorLabelWrap}>
        <Text style={styles.floorLabel}>{currentFloor}</Text>
        <Text style={styles.placeholder}>FLOOR MAP</Text>
      </View>

      {floorSpots.map((spot) => (
        <MapMarker
          key={spot.id}
          spot={spot}
          selected={selectedSpot?.id === spot.id}
          onPress={() => onSpotPress(spot)}
        />
      ))}
    </View>
  );
}

const styles = StyleSheet.create({
  canvas: {
    backgroundColor: colors.sky1,
    flex: 1,
    overflow: 'hidden',
    position: 'relative',
  },
  floorLabelWrap: {
    alignItems: 'center',
    left: 0,
    position: 'absolute',
    right: 0,
    top: '42%',
  },
  floorLabel: {
    color: colors.text,
    fontSize: 64,
    fontWeight: '300',
    opacity: 0.08,
  },
  placeholder: {
    color: colors.mutedForeground,
    fontSize: 13,
    letterSpacing: 0,
    opacity: 0.34,
  },
});
