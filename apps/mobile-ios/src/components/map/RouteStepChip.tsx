import { StyleSheet, Text, View } from 'react-native';
import { colors, radii, spacing } from '../../theme/tokens';
import type { RouteStep } from '../../types/navigation';

type RouteStepChipProps = {
  step: RouteStep;
};

export function RouteStepChip({ step }: RouteStepChipProps) {
  return (
    <View style={styles.chip}>
      <Text style={styles.floor}>{step.floor}</Text>
      <Text style={styles.text}>{step.landmark}{step.distance ? ` / ${step.distance}m` : ''}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  chip: {
    backgroundColor: colors.muted,
    borderRadius: radii.md,
    gap: spacing.xs,
    padding: spacing.md,
  },
  floor: {
    color: colors.primary,
    fontSize: 12,
    fontWeight: '700',
  },
  text: {
    color: colors.text,
    fontSize: 13,
    lineHeight: 18,
  },
});
