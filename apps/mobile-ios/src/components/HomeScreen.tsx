import { router } from 'expo-router';
import { Pressable, SafeAreaView, ScrollView, StyleSheet, Text, View } from 'react-native';
import { colors, radii, shadows, spacing, typography } from '../theme/tokens';
import type { CampusEvent } from '../types/events';
import type { MapSpot } from '../types/navigation';
import { BottomNav } from './BottomNav';
import { CongestionBadge } from './CongestionBadge';
import { AppIcon } from './icons/AppIcon';
import { MapHeroCard } from './MapHeroCard';

type HomeScreenProps = {
  events: CampusEvent[];
};

const recommendedSpots: (MapSpot & { reason: string })[] = [
  { id: 'library', name: '図書館', category: '施設見学', congestion: 'empty', floor: '2F', x: 40, y: 35, reason: '静かに見学できます' },
  { id: 'cafeteria', name: 'カフェテリア', category: '休憩', congestion: 'normal', floor: '2F', x: 60, y: 60, reason: '休憩におすすめ' },
  { id: 'lab', name: '研究室', category: '体験', congestion: 'busy', floor: '3F', x: 45, y: 45, reason: '最新研究を見学' },
];

export function HomeScreen({ events }: HomeScreenProps) {
  const visibleEvents = events.slice(0, 3);

  return (
    <View style={styles.root}>
      <SafeAreaView style={styles.safeArea}>
        <ScrollView contentContainerStyle={styles.scrollContent} showsVerticalScrollIndicator={false}>
          <View style={styles.hero}>
            <Text style={styles.logo}>Nexus</Text>
            <Text style={styles.heroCopy}>オープンキャンパスへようこそ</Text>
            <MapHeroCard onOpenMap={() => router.push('/map')} />
          </View>

          <View style={styles.section}>
            <View style={styles.sectionHeader}>
              <AppIcon name="calendar" size={18} color={colors.mutedForeground} />
              <Text style={typography.sectionTitle}>次のイベント</Text>
            </View>

            <View style={styles.stack}>
              {visibleEvents.map((event) => (
                <Pressable
                  key={event.id}
                  onPress={() => router.push({ pathname: '/events', params: { eventId: event.id } })}
                  style={({ pressed }) => [styles.card, pressed && styles.pressed]}
                >
                  <View style={styles.eventRow}>
                    <Text style={styles.timePill}>{event.time}</Text>
                    <View style={styles.cardBody}>
                      <Text style={styles.cardTitle}>{event.title}</Text>
                      <View style={styles.metaRow}>
                        <AppIcon name="mapPin" size={12} color={colors.mutedForeground} />
                        <Text style={styles.metaText}>{event.location} / {event.department}</Text>
                      </View>
                      <Pressable onPress={() => router.push('/map')} style={styles.linkRow}>
                        <AppIcon name="map" size={12} color={colors.primary} />
                        <Text style={styles.linkText}>マップで場所を見る</Text>
                        <AppIcon name="arrowRight" size={12} color={colors.primary} />
                      </Pressable>
                    </View>
                  </View>
                </Pressable>
              ))}
            </View>
          </View>

          <View style={styles.section}>
            <View style={styles.sectionHeader}>
              <AppIcon name="mapPin" size={18} color={colors.mutedForeground} />
              <Text style={typography.sectionTitle}>おすすめスポット</Text>
            </View>

            <View style={styles.stack}>
              {recommendedSpots.map((spot) => (
                <View key={spot.id} style={styles.card}>
                  <View style={styles.spotRow}>
                    <View style={styles.spotIcon}>
                      <AppIcon name="mapPin" size={18} color={colors.primary} />
                    </View>
                    <View style={styles.cardBody}>
                      <Text style={styles.cardTitle}>{spot.name}</Text>
                      <Text style={styles.metaText}>{spot.reason} / {spot.floor}</Text>
                      <CongestionBadge level={spot.congestion} compact />
                      <Pressable onPress={() => router.push({ pathname: '/map', params: { spotName: spot.name } })} style={styles.linkRow}>
                        <AppIcon name="map" size={12} color={colors.primary} />
                        <Text style={styles.linkText}>マップで見る</Text>
                        <AppIcon name="arrowRight" size={12} color={colors.primary} />
                      </Pressable>
                    </View>
                  </View>
                </View>
              ))}
            </View>
          </View>
        </ScrollView>
      </SafeAreaView>
      <BottomNav />
    </View>
  );
}

const styles = StyleSheet.create({
  root: {
    backgroundColor: colors.sky0,
    flex: 1,
  },
  safeArea: {
    flex: 1,
  },
  scrollContent: {
    paddingBottom: 112,
  },
  hero: {
    backgroundColor: colors.sky1,
    gap: spacing.md,
    paddingBottom: spacing.xl,
    paddingHorizontal: spacing.lg,
    paddingTop: spacing.xl,
  },
  logo: {
    ...typography.title,
    fontSize: 28,
  },
  heroCopy: {
    ...typography.body,
    color: colors.mutedForeground,
  },
  section: {
    paddingHorizontal: spacing.lg,
    paddingTop: spacing.xl,
  },
  sectionHeader: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: spacing.sm,
    marginBottom: spacing.lg,
  },
  stack: {
    gap: spacing.md,
  },
  card: {
    backgroundColor: colors.surface,
    borderRadius: radii.lg,
    padding: spacing.lg,
    ...shadows.level1,
  },
  pressed: {
    opacity: 0.78,
  },
  eventRow: {
    alignItems: 'flex-start',
    flexDirection: 'row',
    gap: spacing.md,
  },
  timePill: {
    backgroundColor: colors.primaryWeak,
    borderRadius: radii.pill,
    color: colors.primary,
    fontSize: 12,
    fontWeight: '700',
    paddingHorizontal: spacing.md,
    paddingVertical: 5,
  },
  spotRow: {
    alignItems: 'flex-start',
    flexDirection: 'row',
    gap: spacing.md,
  },
  spotIcon: {
    alignItems: 'center',
    backgroundColor: colors.muted,
    borderRadius: radii.md,
    height: 40,
    justifyContent: 'center',
    width: 40,
  },
  cardBody: {
    flex: 1,
    gap: spacing.sm,
    minWidth: 0,
  },
  cardTitle: {
    color: colors.text,
    fontSize: 16,
    fontWeight: '600',
    lineHeight: 22,
  },
  metaRow: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: 6,
  },
  metaText: {
    color: colors.mutedForeground,
    flexShrink: 1,
    fontSize: 12,
    lineHeight: 18,
  },
  linkRow: {
    alignItems: 'center',
    alignSelf: 'flex-start',
    flexDirection: 'row',
    gap: 5,
  },
  linkText: {
    color: colors.primary,
    fontSize: 12,
    fontWeight: '600',
  },
});
