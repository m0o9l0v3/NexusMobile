import { Pressable, StyleSheet, Text, View } from 'react-native';
import Svg, { Circle, Line, Path, Rect } from 'react-native-svg';
import { colors, radii, shadows, spacing, typography } from '../theme/tokens';
import { AppIcon } from './icons/AppIcon';

type MapHeroCardProps = {
  onOpenMap: () => void;
  currentLocation?: string;
  currentFloor?: string;
};

export function MapHeroCard({
  onOpenMap,
  currentLocation = '受付付近',
  currentFloor = '1F',
}: MapHeroCardProps) {
  return (
    <Pressable
      accessibilityRole="button"
      onPress={onOpenMap}
      style={({ pressed }) => [styles.card, pressed && styles.pressed]}
    >
      <View style={styles.visual}>
        <Svg width={118} height={118} viewBox="0 0 120 120">
          <Line x1="20" y1="0" x2="20" y2="120" stroke={colors.primary} strokeWidth="1" opacity="0.22" />
          <Line x1="50" y1="0" x2="50" y2="120" stroke={colors.primary} strokeWidth="1" opacity="0.22" />
          <Line x1="80" y1="0" x2="80" y2="120" stroke={colors.primary} strokeWidth="1" opacity="0.22" />
          <Line x1="0" y1="30" x2="120" y2="30" stroke={colors.primary} strokeWidth="1" opacity="0.22" />
          <Line x1="0" y1="60" x2="120" y2="60" stroke={colors.primary} strokeWidth="1" opacity="0.22" />
          <Line x1="0" y1="90" x2="120" y2="90" stroke={colors.primary} strokeWidth="1" opacity="0.22" />
          <Rect x="15" y="25" width="15" height="25" rx="2" fill={colors.primary} opacity="0.18" />
          <Rect x="45" y="35" width="20" height="35" rx="2" fill={colors.primary} opacity="0.2" />
          <Rect x="75" y="20" width="18" height="30" rx="2" fill={colors.primary} opacity="0.18" />
          <Path d="M30 80 Q50 70, 70 75 T100 65" stroke={colors.primary} strokeWidth="2" fill="none" strokeDasharray="4 4" opacity="0.36" />
          <Circle cx="30" cy="80" r="4" fill={colors.primary} opacity="0.35" />
          <Circle cx="100" cy="65" r="4" fill={colors.primary} opacity="0.35" />
        </Svg>
      </View>

      <View style={styles.content}>
        <Text style={typography.caption}>{currentLocation} / {currentFloor}</Text>
        <Text style={styles.title}>キャンパスマップ</Text>
        <Text style={styles.copy}>目的地を探して、現在地からの移動を確認できます。</Text>
        <View style={styles.cta}>
          <AppIcon name="map" size={16} color={colors.primaryForeground} />
          <Text style={styles.ctaText}>マップを開く</Text>
        </View>
      </View>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  card: {
    backgroundColor: colors.surface,
    borderRadius: radii.xl,
    minHeight: 190,
    overflow: 'hidden',
    padding: spacing.xl,
    position: 'relative',
    ...shadows.level2,
  },
  pressed: {
    opacity: 0.86,
    transform: [{ scale: 0.99 }],
  },
  visual: {
    opacity: 0.75,
    position: 'absolute',
    right: 8,
    top: 8,
  },
  content: {
    gap: spacing.sm,
    maxWidth: '78%',
  },
  title: {
    ...typography.sectionTitle,
    fontWeight: '700',
  },
  copy: {
    ...typography.body,
    color: colors.mutedForeground,
  },
  cta: {
    alignItems: 'center',
    alignSelf: 'flex-start',
    backgroundColor: colors.primary,
    borderRadius: radii.pill,
    flexDirection: 'row',
    gap: spacing.sm,
    marginTop: spacing.sm,
    paddingHorizontal: spacing.lg,
    paddingVertical: 10,
  },
  ctaText: {
    color: colors.primaryForeground,
    fontSize: 14,
    fontWeight: '600',
  },
});
