import { Pressable, StyleSheet, Text, View } from 'react-native';
import { colors, radii, shadows, spacing } from '../../theme/tokens';

type FloorSwitchProps = {
  floors: string[];
  currentFloor: string;
  onFloorChange: (floor: string) => void;
};

export function FloorSwitch({ floors, currentFloor, onFloorChange }: FloorSwitchProps) {
  return (
    <View style={styles.wrap}>
      {floors.map((floor) => {
        const active = floor === currentFloor;
        return (
          <Pressable
            key={floor}
            onPress={() => onFloorChange(floor)}
            style={[styles.item, active && styles.activeItem]}
          >
            <Text style={[styles.label, active && styles.activeLabel]}>{floor}</Text>
          </Pressable>
        );
      })}
    </View>
  );
}

const styles = StyleSheet.create({
  wrap: {
    alignSelf: 'center',
    backgroundColor: colors.floatingSurface,
    borderColor: colors.border,
    borderWidth: StyleSheet.hairlineWidth,
    borderRadius: radii.pill,
    flexDirection: 'row',
    gap: 2,
    padding: 4,
    ...shadows.level2,
  },
  item: {
    borderRadius: radii.pill,
    paddingHorizontal: spacing.md,
    paddingVertical: 7,
  },
  activeItem: {
    backgroundColor: colors.primary,
  },
  label: {
    color: colors.subtext,
    fontSize: 12,
    fontWeight: '700',
  },
  activeLabel: {
    color: colors.primaryForeground,
  },
});
