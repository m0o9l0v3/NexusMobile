import { Pressable, StyleSheet, Text, View } from 'react-native';
import { colors, radii, shadows, spacing } from '../../theme/tokens';
import type { CampusEvent } from '../../types/events';
import type { MapSpot } from '../../types/navigation';
import { AppIcon } from '../icons/AppIcon';

type BottomSheetProps = {
  spot?: MapSpot;
  event?: CampusEvent;
  onGuide: () => void;
  onShowDetail: () => void;
};

export function BottomSheet({ spot, event, onGuide, onShowDetail }: BottomSheetProps) {
  if (!spot) {
    return null;
  }

  const hasEventDetail = Boolean(event);

  return (
    <View style={styles.wrap} pointerEvents="box-none">
      <View style={styles.card}>
        <View style={styles.handle} />
        <View style={styles.header}>
          <View style={styles.pinIcon}>
            <AppIcon name={spot.kind === 'current' ? 'navigation' : 'mapPin'} size={17} color={colors.primaryForeground} />
          </View>
          <View style={styles.titleBlock}>
            <Text style={styles.label}>{spot.kind === 'current' ? '現在地' : '次の目的地'}</Text>
            <Text style={styles.title} numberOfLines={1}>{spot.name}</Text>
          </View>
          <Text style={styles.floorText}>{spot.floor}</Text>
        </View>

        <View style={styles.infoRow}>
          <View style={styles.infoItem}>
            <Text style={styles.infoLabel}>関連イベント</Text>
            <Text style={styles.infoText} numberOfLines={1}>{event?.title ?? '受付で確認'}</Text>
          </View>
          <View style={styles.infoItemCompact}>
            <Text style={styles.infoLabel}>開始</Text>
            <Text style={styles.infoText}>{event?.time ?? '--:--'}</Text>
          </View>
        </View>

        <View style={styles.metaRow}>
          <AppIcon name="clock" size={14} color={colors.subtext} />
          <Text style={styles.metaText}>{spot.travelEstimate ?? '受付からの目安はスタッフへ確認'}</Text>
        </View>

        <View style={styles.actions}>
          <Pressable onPress={onGuide} style={({ pressed }) => [styles.primaryButton, pressed && styles.pressed]}>
            <AppIcon name="navigation" size={16} color={colors.primaryForeground} />
            <Text style={styles.primaryButtonText}>案内する</Text>
          </Pressable>
          <Pressable
            disabled={!hasEventDetail}
            onPress={onShowDetail}
            style={({ pressed }) => [styles.secondaryButton, !hasEventDetail && styles.disabledButton, pressed && hasEventDetail && styles.pressed]}
          >
            <Text style={[styles.secondaryButtonText, !hasEventDetail && styles.disabledButtonText]}>詳細</Text>
          </Pressable>
        </View>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  wrap: {
    bottom: 82,
    left: spacing.lg,
    position: 'absolute',
    right: spacing.lg,
    zIndex: 40,
  },
  card: {
    backgroundColor: colors.floatingSurface,
    borderColor: colors.border,
    borderRadius: radii.xl,
    borderWidth: StyleSheet.hairlineWidth,
    gap: spacing.md,
    padding: spacing.lg,
    ...shadows.level2,
  },
  handle: {
    alignSelf: 'center',
    backgroundColor: colors.border,
    borderRadius: radii.pill,
    height: 4,
    marginTop: -4,
    width: 34,
  },
  header: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: spacing.md,
  },
  pinIcon: {
    alignItems: 'center',
    backgroundColor: colors.primary,
    borderRadius: radii.pill,
    height: 34,
    justifyContent: 'center',
    width: 34,
  },
  titleBlock: {
    flex: 1,
    minWidth: 0,
  },
  label: {
    color: colors.accent,
    fontSize: 11,
    fontWeight: '900',
  },
  title: {
    color: colors.text,
    fontSize: 18,
    fontWeight: '900',
    lineHeight: 25,
  },
  floorText: {
    color: colors.subtext,
    fontSize: 12,
    fontWeight: '900',
  },
  infoRow: {
    flexDirection: 'row',
    gap: spacing.md,
  },
  infoItem: {
    flex: 1,
    minWidth: 0,
  },
  infoItemCompact: {
    minWidth: 58,
  },
  infoLabel: {
    color: colors.subtext,
    fontSize: 11,
    fontWeight: '800',
  },
  infoText: {
    color: colors.text,
    fontSize: 13,
    fontWeight: '800',
    lineHeight: 19,
    marginTop: 2,
  },
  metaRow: {
    alignItems: 'center',
    backgroundColor: colors.surfaceSoft,
    borderRadius: radii.md,
    flexDirection: 'row',
    gap: spacing.sm,
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm,
  },
  metaText: {
    color: colors.subtext,
    flex: 1,
    fontSize: 12,
    fontWeight: '700',
  },
  actions: {
    flexDirection: 'row',
    gap: spacing.md,
  },
  primaryButton: {
    alignItems: 'center',
    backgroundColor: colors.primary,
    borderRadius: radii.md,
    flex: 1,
    flexDirection: 'row',
    gap: spacing.sm,
    justifyContent: 'center',
    minHeight: 44,
  },
  primaryButtonText: {
    color: colors.primaryForeground,
    fontSize: 14,
    fontWeight: '900',
  },
  secondaryButton: {
    alignItems: 'center',
    backgroundColor: colors.surfaceSoft,
    borderRadius: radii.md,
    justifyContent: 'center',
    minHeight: 44,
    paddingHorizontal: spacing.xl,
  },
  secondaryButtonText: {
    color: colors.primary,
    fontSize: 14,
    fontWeight: '900',
  },
  disabledButton: {
    opacity: 0.58,
  },
  disabledButtonText: {
    color: colors.muted,
  },
  pressed: {
    opacity: 0.78,
  },
});
