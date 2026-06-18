import { Pressable, StyleSheet, Text, View } from 'react-native';
import { colors, radii, shadows, spacing } from '../../theme/tokens';
import type { MapSpot, RouteInfo } from '../../types/navigation';
import { CongestionBadge } from '../CongestionBadge';
import { AppIcon } from '../icons/AppIcon';
import { RouteStepChip } from './RouteStepChip';

type BottomSheetProps = {
  isOpen: boolean;
  mode: 'spot' | 'route' | null;
  spot?: MapSpot;
  routeInfo?: RouteInfo;
  onClose: () => void;
  onSetOrigin: (spot: MapSpot) => void;
  onSetDestination: (spot: MapSpot) => void;
};

export function BottomSheet({
  isOpen,
  mode,
  spot,
  routeInfo,
  onClose,
  onSetOrigin,
  onSetDestination,
}: BottomSheetProps) {
  if (!isOpen) {
    return null;
  }

  return (
    <View style={styles.layer} pointerEvents="box-none">
      <Pressable style={styles.backdrop} onPress={onClose} />
      <View style={styles.sheet}>
        <View style={styles.handle} />
        {mode === 'spot' && spot ? (
          <View style={styles.content}>
            <View style={styles.sheetHeader}>
              <View style={styles.titleWrap}>
                <Text style={styles.title}>{spot.name}</Text>
                <Text style={styles.meta}>{spot.floor} / {spot.category}</Text>
              </View>
              <Pressable onPress={onClose} style={styles.closeButton}>
                <AppIcon name="x" size={20} color={colors.text} />
              </Pressable>
            </View>
            <CongestionBadge level={spot.congestion} />
            {spot.tags?.length ? <Text style={styles.description}>{spot.tags.join(' / ')}</Text> : null}
            <View style={styles.actions}>
              <Pressable onPress={() => onSetOrigin(spot)} style={[styles.actionButton, styles.secondaryAction]}>
                <AppIcon name="navigation" size={16} color={colors.primary} />
                <Text style={styles.secondaryActionText}>出発地</Text>
              </Pressable>
              <Pressable onPress={() => onSetDestination(spot)} style={[styles.actionButton, styles.primaryAction]}>
                <AppIcon name="mapPin" size={16} color={colors.primaryForeground} />
                <Text style={styles.primaryActionText}>目的地</Text>
              </Pressable>
            </View>
          </View>
        ) : null}

        {mode === 'route' && routeInfo ? (
          <View style={styles.content}>
            <View style={styles.sheetHeader}>
              <View style={styles.titleWrap}>
                <Text style={styles.title}>ルート案内</Text>
                <Text style={styles.meta}>{routeInfo.distance}m / 約{routeInfo.duration}分</Text>
              </View>
              <Pressable onPress={onClose} style={styles.closeButton}>
                <AppIcon name="x" size={20} color={colors.text} />
              </Pressable>
            </View>
            {routeInfo.nextLandmark ? <Text style={styles.description}>次: {routeInfo.nextLandmark}{routeInfo.nextFloor ? ` / ${routeInfo.nextFloor}` : ''}</Text> : null}
            <View style={styles.stepStack}>
              {routeInfo.steps.map((step) => (
                <RouteStepChip key={`${step.floor}-${step.landmark}`} step={step} />
              ))}
            </View>
          </View>
        ) : null}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  layer: {
    ...StyleSheet.absoluteFillObject,
    justifyContent: 'flex-end',
    zIndex: 60,
  },
  backdrop: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: 'transparent',
  },
  sheet: {
    backgroundColor: colors.surface,
    borderTopLeftRadius: radii.xl,
    borderTopRightRadius: radii.xl,
    paddingBottom: spacing.xl,
    paddingHorizontal: spacing.lg,
    ...shadows.level3,
  },
  handle: {
    alignSelf: 'center',
    backgroundColor: colors.outline,
    borderRadius: radii.pill,
    height: 4,
    marginVertical: spacing.md,
    width: 40,
  },
  content: {
    gap: spacing.md,
  },
  sheetHeader: {
    alignItems: 'flex-start',
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  titleWrap: {
    flex: 1,
    gap: 4,
  },
  title: {
    color: colors.text,
    fontSize: 20,
    fontWeight: '700',
    lineHeight: 28,
  },
  meta: {
    color: colors.mutedForeground,
    fontSize: 13,
  },
  closeButton: {
    alignItems: 'center',
    borderRadius: radii.pill,
    height: 40,
    justifyContent: 'center',
    width: 40,
  },
  description: {
    color: colors.mutedForeground,
    fontSize: 14,
    lineHeight: 21,
  },
  actions: {
    flexDirection: 'row',
    gap: spacing.md,
  },
  actionButton: {
    alignItems: 'center',
    borderRadius: radii.lg,
    flex: 1,
    flexDirection: 'row',
    gap: spacing.sm,
    justifyContent: 'center',
    paddingVertical: spacing.md,
  },
  primaryAction: {
    backgroundColor: colors.primary,
  },
  secondaryAction: {
    backgroundColor: colors.primaryWeak,
  },
  primaryActionText: {
    color: colors.primaryForeground,
    fontSize: 14,
    fontWeight: '700',
  },
  secondaryActionText: {
    color: colors.primary,
    fontSize: 14,
    fontWeight: '700',
  },
  stepStack: {
    gap: spacing.sm,
  },
});
