import { Pressable, StyleSheet, Text, View } from 'react-native';
import { colors, radii, spacing } from '../../theme/tokens';
import type { MapSpot } from '../../types/navigation';
import { CongestionBadge } from '../CongestionBadge';
import { AppIcon } from '../icons/AppIcon';

type SuggestListItemProps = {
  spot: MapSpot;
  onPress: () => void;
};

export function SuggestListItem({ spot, onPress }: SuggestListItemProps) {
  return (
    <Pressable onPress={onPress} style={({ pressed }) => [styles.row, pressed && styles.pressed]}>
      <View style={styles.icon}>
        <AppIcon name="mapPin" size={16} color={colors.primary} />
      </View>
      <View style={styles.body}>
        <Text style={styles.title}>{spot.name}</Text>
        <Text style={styles.meta}>{spot.floor} / {spot.category}</Text>
      </View>
      <CongestionBadge level={spot.congestion} compact />
    </Pressable>
  );
}

const styles = StyleSheet.create({
  row: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: spacing.md,
    paddingVertical: spacing.md,
  },
  pressed: {
    opacity: 0.72,
  },
  icon: {
    alignItems: 'center',
    backgroundColor: colors.muted,
    borderRadius: radii.md,
    height: 36,
    justifyContent: 'center',
    width: 36,
  },
  body: {
    flex: 1,
  },
  title: {
    color: colors.text,
    fontSize: 14,
    fontWeight: '700',
  },
  meta: {
    color: colors.mutedForeground,
    fontSize: 12,
    marginTop: 2,
  },
});
