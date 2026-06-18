import { router, usePathname } from 'expo-router';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { colors, shadows, spacing } from '../theme/tokens';
import { AppIcon } from './icons/AppIcon';

type TabId = 'home' | 'map' | 'events';

type NavItem = {
  id: TabId;
  label: string;
  href: '/' | '/map' | '/events';
  icon: 'home' | 'map' | 'calendar';
  elevated?: boolean;
};

const items: NavItem[] = [
  { id: 'home', label: 'ホーム', href: '/', icon: 'home' },
  { id: 'map', label: 'マップ', href: '/map', icon: 'map', elevated: true },
  { id: 'events', label: 'イベント', href: '/events', icon: 'calendar' },
];

const getActiveTab = (pathname: string): TabId => {
  if (pathname.startsWith('/map')) return 'map';
  if (pathname.startsWith('/events')) return 'events';
  return 'home';
};

export function BottomNav() {
  const pathname = usePathname();
  const insets = useSafeAreaInsets();
  const activeTab = getActiveTab(pathname);

  return (
    <View style={[styles.wrap, { paddingBottom: Math.max(insets.bottom, spacing.sm) }]}>
      <View style={styles.row}>
        {items.map((item) => {
          const active = item.id === activeTab;
          const iconColor = active || item.elevated ? colors.primary : colors.mutedForeground;
          return (
            <Pressable
              accessibilityRole="tab"
              accessibilityState={{ selected: active }}
              key={item.id}
              onPress={() => router.push(item.href)}
              style={({ pressed }) => [
                styles.item,
                item.elevated && active && styles.elevatedItem,
                pressed && styles.pressed,
              ]}
            >
              {item.elevated && active ? <View style={styles.elevatedDisc} /> : null}
              <View style={styles.itemContent}>
                <AppIcon name={item.icon} size={22} color={iconColor} />
                <Text style={[styles.label, active ? styles.activeLabel : styles.inactiveLabel]}>{item.label}</Text>
              </View>
            </Pressable>
          );
        })}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  wrap: {
    backgroundColor: colors.surface,
    borderTopColor: colors.outline,
    borderTopWidth: StyleSheet.hairlineWidth,
    bottom: 0,
    left: 0,
    position: 'absolute',
    right: 0,
    zIndex: 50,
  },
  row: {
    alignItems: 'flex-end',
    flexDirection: 'row',
    justifyContent: 'space-around',
    paddingHorizontal: spacing.lg,
    paddingTop: spacing.sm,
  },
  item: {
    alignItems: 'center',
    flex: 1,
    justifyContent: 'center',
    minHeight: 56,
    paddingVertical: spacing.sm,
    position: 'relative',
  },
  elevatedItem: {
    transform: [{ translateY: -6 }, { scale: 1.04 }],
  },
  elevatedDisc: {
    backgroundColor: colors.surface,
    borderRadius: 32,
    height: 64,
    position: 'absolute',
    top: -4,
    width: 64,
    ...shadows.level3,
  },
  itemContent: {
    alignItems: 'center',
    gap: 3,
    zIndex: 1,
  },
  label: {
    fontSize: 11,
    fontWeight: '600',
  },
  activeLabel: {
    color: colors.primary,
  },
  inactiveLabel: {
    color: colors.mutedForeground,
  },
  pressed: {
    opacity: 0.72,
  },
});
