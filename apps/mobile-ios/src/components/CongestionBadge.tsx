import { StyleSheet, Text, View } from 'react-native';
import { colors, radii } from '../theme/tokens';
import { congestionLabels, type CongestionLevel } from '../types/navigation';

type CongestionBadgeProps = {
  level: CongestionLevel;
  compact?: boolean;
};

const congestionColor: Record<CongestionLevel, string> = {
  empty: colors.empty,
  normal: colors.normal,
  busy: colors.busy,
  full: colors.full,
};

export function CongestionBadge({ level, compact = false }: CongestionBadgeProps) {
  return (
    <View style={[styles.badge, compact && styles.compact]}>
      <View style={[styles.dot, { backgroundColor: congestionColor[level] }]} />
      <Text style={[styles.label, compact && styles.compactLabel]}>{congestionLabels[level]}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  badge: {
    alignSelf: 'flex-start',
    alignItems: 'center',
    backgroundColor: colors.surfaceSoft,
    borderRadius: radii.pill,
    flexDirection: 'row',
    gap: 6,
    paddingHorizontal: 10,
    paddingVertical: 5,
  },
  compact: {
    paddingHorizontal: 8,
    paddingVertical: 4,
  },
  dot: {
    borderRadius: 4,
    height: 8,
    width: 8,
  },
  label: {
    color: colors.text,
    fontSize: 12,
    fontWeight: '600',
  },
  compactLabel: {
    fontSize: 11,
  },
});
