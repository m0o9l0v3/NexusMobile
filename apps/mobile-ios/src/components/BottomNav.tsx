import { router, usePathname } from 'expo-router';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { colors, spacing } from '../theme/tokens';
import { AppIcon } from './icons/AppIcon';

type TabId = 'home' | 'map' | 'events';

type NavItem = {
  id: TabId;
  label: string;
  href: '/' | '/map' | '/events';
  icon: 'home' | 'map' | 'calendar';
};

const items: NavItem[] = [
  { id: 'home', label: 'ホーム', href: '/', icon: 'home' },
  { id: 'map', label: 'マップ', href: '/map', icon: 'map' },
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
          const iconColor = active ? colors.accent : colors.muted;
          return (
            <Pressable
              accessibilityRole="tab"
              accessibilityState={{ selected: active }}
              key={item.id}
              onPress={() => router.push(item.href)}
              style={({ pressed }) => [styles.item, pressed && styles.pressed]}
            >
              <View style={[styles.indicator, active && styles.activeIndicator]} />
              <AppIcon name={item.icon} size={21} color={iconColor} />
              <Text style={[styles.label, active ? styles.activeLabel : styles.inactiveLabel]}>{item.label}</Text>
            </Pressable>
          );
        })}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  wrap: {
    backgroundColor: colors.floatingSurface,
    borderTopColor: colors.border,
    borderTopWidth: StyleSheet.hairlineWidth,
    bottom: 0,
    left: 0,
    position: 'absolute',
    right: 0,
    zIndex: 35,
  },
  row: {
    alignItems: 'center',
    flexDirection: 'row',
    justifyContent: 'space-around',
    paddingHorizontal: spacing.lg,
    paddingTop: spacing.xs,
  },
  item: {
    alignItems: 'center',
    flex: 1,
    gap: 3,
    justifyContent: 'center',
    minHeight: 58,
    paddingVertical: spacing.sm,
  },
  indicator: {
    backgroundColor: 'transparent',
    borderRadius: 2,
    height: 3,
    marginBottom: 2,
    width: 28,
  },
  activeIndicator: {
    backgroundColor: colors.accent,
  },
  label: {
    fontSize: 11,
    fontWeight: '800',
  },
  activeLabel: {
    color: colors.accent,
  },
  inactiveLabel: {
    color: colors.subtext,
  },
  pressed: {
    opacity: 0.72,
  },
});
