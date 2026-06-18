import { router } from 'expo-router';
import { useEffect, useMemo, useState } from 'react';
import { Pressable, SafeAreaView, ScrollView, StyleSheet, Text, View } from 'react-native';
import {
  eventCategories,
  getEventStatus,
  getSpotNameForEvent,
  getStartGuide,
  getStatusLabel,
  sortEventsByTime,
} from '../data/openCampus';
import { colors, radii, spacing, typography } from '../theme/tokens';
import type { CampusEvent } from '../types/events';
import { BottomNav } from './BottomNav';
import { AppCard } from './common/AppCard';
import { SectionHeader } from './common/SectionHeader';
import { StatusPill } from './common/StatusPill';
import { AppIcon } from './icons/AppIcon';

type EventsScreenProps = {
  events: CampusEvent[];
  initialEventId?: string;
};

export function EventsScreen({ events, initialEventId }: EventsScreenProps) {
  const [selectedCategory, setSelectedCategory] = useState('すべて');
  const [selectedEvent, setSelectedEvent] = useState<CampusEvent | undefined>();

  useEffect(() => {
    if (!initialEventId) return;
    setSelectedEvent(events.find((event) => event.id === initialEventId));
  }, [events, initialEventId]);

  const filteredEvents = useMemo(() => {
    const sorted = sortEventsByTime(events);
    if (selectedCategory === 'すべて') return sorted;
    return sorted.filter((event) => event.category === selectedCategory);
  }, [events, selectedCategory]);

  return (
    <View style={styles.root}>
      <SafeAreaView style={styles.safeArea}>
        <View style={styles.header}>
          <Text style={styles.kicker}>本日の流れ</Text>
          <Text style={typography.title}>イベント</Text>
          <Text style={styles.headerCopy}>時間だけでなく、そこで何を確認できるかを見ながら回れます。</Text>
          <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.chipRow}>
            {eventCategories.map((category) => {
              const active = selectedCategory === category;
              return (
                <Pressable
                  key={category}
                  onPress={() => setSelectedCategory(category)}
                  style={({ pressed }) => [styles.chip, active && styles.activeChip, pressed && styles.pressed]}
                >
                  <Text style={[styles.chipText, active && styles.activeChipText]}>{category}</Text>
                </Pressable>
              );
            })}
          </ScrollView>
        </View>

        <ScrollView contentContainerStyle={styles.timelineContent} showsVerticalScrollIndicator={false}>
          <View style={styles.sectionIntro}>
            <SectionHeader title="確認できること" caption="保護者向け相談や実習体験など、目的に合わせてカードの状態を確認してください。" icon="info" />
          </View>

          <View style={styles.stack}>
            {filteredEvents.map((event) => {
              const status = getEventStatus(event, events);
              const isDimmed = status === 'ended';
              return (
                <Pressable
                  key={event.id}
                  onPress={() => setSelectedEvent(event)}
                  style={({ pressed }) => [styles.cardPressable, pressed && styles.pressed]}
                >
                  <AppCard
                    accent={status === 'live' || status === 'next' || event.priority === 'support'}
                    style={[
                      styles.eventCard,
                      status === 'live' && styles.liveCard,
                      status === 'next' && styles.nextCard,
                      isDimmed && styles.endedCard,
                    ]}
                  >
                    <View style={styles.eventHeader}>
                      <View style={styles.timeColumn}>
                        <Text style={[styles.timeText, isDimmed && styles.dimText]}>{event.time}</Text>
                        <Text style={styles.timeRange}>{event.endTime ?? '--:--'}まで</Text>
                      </View>
                      <View style={styles.eventMain}>
                        <View style={styles.statusRow}>
                          <StatusPill label={getStatusLabel(status)} status={status} />
                          <Text style={styles.startGuide}>{getStartGuide(event)}</Text>
                        </View>
                        <Text style={[styles.eventTitle, isDimmed && styles.dimText]}>{event.title}</Text>
                        <View style={styles.metaWrap}>
                          <View style={styles.metaRow}>
                            <AppIcon name="mapPin" size={13} color={colors.subtext} />
                            <Text style={styles.metaText}>
                              {event.location}
                              {event.floor ? ` / ${event.floor}` : ''}
                            </Text>
                          </View>
                          <View style={styles.metaRow}>
                            <AppIcon name="users" size={13} color={colors.subtext} />
                            <Text style={styles.metaText}>{event.audience ?? event.category ?? '学生・保護者'}</Text>
                          </View>
                        </View>
                      </View>
                    </View>

                    <View style={styles.checkBlock}>
                      <Text style={styles.checkLabel}>このイベントで確認できること</Text>
                      <Text style={styles.description}>{event.description}</Text>
                      {event.checkpoints?.length ? (
                        <View style={styles.checkList}>
                          {event.checkpoints.slice(0, 3).map((checkpoint) => (
                            <View key={checkpoint} style={styles.checkPill}>
                              <Text style={styles.checkPillText}>{checkpoint}</Text>
                            </View>
                          ))}
                        </View>
                      ) : null}
                    </View>
                  </AppCard>
                </Pressable>
              );
            })}
          </View>

          {filteredEvents.length === 0 ? (
            <Text style={styles.emptyText}>該当するイベントはありません。受付で今日の流れをご確認ください。</Text>
          ) : null}
        </ScrollView>
      </SafeAreaView>

      {selectedEvent ? <EventDetailSheet event={selectedEvent} events={events} onClose={() => setSelectedEvent(undefined)} /> : null}
      <BottomNav />
    </View>
  );
}

function EventDetailSheet({ event, events, onClose }: { event: CampusEvent; events: CampusEvent[]; onClose: () => void }) {
  const status = getEventStatus(event, events);

  return (
    <View style={styles.sheetLayer}>
      <Pressable style={styles.backdrop} onPress={onClose} />
      <View style={styles.sheet}>
        <View style={styles.handle} />
        <View style={styles.sheetHeader}>
          <View style={styles.sheetText}>
            <StatusPill label={getStatusLabel(status)} status={status} />
            <Text style={styles.sheetTitle}>{event.title}</Text>
            <Text style={styles.sheetMeta}>
              {event.time} - {event.endTime ?? '--:--'} / {event.location}
              {event.floor ? ` / ${event.floor}` : ''}
            </Text>
          </View>
          <Pressable onPress={onClose} style={styles.closeButton}>
            <AppIcon name="x" size={20} color={colors.text} />
          </Pressable>
        </View>

        <View style={styles.tagRow}>
          <Text style={styles.primaryTag}>{event.audience ?? '学生・保護者'}</Text>
          {event.category ? <Text style={styles.neutralTag}>{event.category}</Text> : null}
          <Text style={styles.neutralTag}>{event.department}</Text>
        </View>

        <Text style={styles.sheetDescription}>{event.description}</Text>

        {event.checkpoints?.length ? (
          <View style={styles.sheetCheckSection}>
            <Text style={styles.sheetSectionTitle}>この時間で確認できること</Text>
            {event.checkpoints.map((checkpoint) => (
              <View key={checkpoint} style={styles.sheetCheckRow}>
                <AppIcon name="check" size={14} color={colors.accent} />
                <Text style={styles.sheetCheckText}>{checkpoint}</Text>
              </View>
            ))}
          </View>
        ) : null}

        <Pressable
          onPress={() => {
            onClose();
            router.push({ pathname: '/map', params: { spotName: getSpotNameForEvent(event) } });
          }}
          style={({ pressed }) => [styles.mapButton, pressed && styles.pressed]}
        >
          <AppIcon name="map" size={17} color={colors.primaryForeground} />
          <Text style={styles.mapButtonText}>場所を見る</Text>
        </Pressable>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  root: {
    backgroundColor: colors.background,
    flex: 1,
  },
  safeArea: {
    flex: 1,
  },
  header: {
    backgroundColor: colors.surface,
    borderBottomColor: colors.border,
    borderBottomWidth: StyleSheet.hairlineWidth,
    gap: spacing.xs,
    paddingHorizontal: spacing.lg,
    paddingTop: spacing.lg,
  },
  kicker: {
    color: colors.accent,
    fontSize: 12,
    fontWeight: '800',
  },
  headerCopy: {
    color: colors.subtext,
    fontSize: 13,
    lineHeight: 19,
    marginTop: spacing.xs,
  },
  chipRow: {
    gap: spacing.sm,
    paddingBottom: spacing.md,
    paddingTop: spacing.md,
  },
  chip: {
    backgroundColor: colors.surfaceSoft,
    borderColor: colors.border,
    borderRadius: radii.pill,
    borderWidth: StyleSheet.hairlineWidth,
    paddingHorizontal: spacing.md,
    paddingVertical: 8,
  },
  activeChip: {
    backgroundColor: colors.primary,
    borderColor: colors.primary,
  },
  chipText: {
    color: colors.text,
    fontSize: 12,
    fontWeight: '700',
  },
  activeChipText: {
    color: colors.primaryForeground,
  },
  timelineContent: {
    paddingBottom: 112,
  },
  sectionIntro: {
    paddingHorizontal: spacing.lg,
    paddingTop: spacing.xl,
  },
  stack: {
    gap: spacing.md,
    paddingHorizontal: spacing.lg,
    paddingTop: spacing.lg,
  },
  cardPressable: {
    borderRadius: radii.lg,
  },
  eventCard: {
    gap: spacing.lg,
  },
  liveCard: {
    backgroundColor: '#FBFDFF',
  },
  nextCard: {
    borderColor: 'rgba(26, 115, 232, 0.22)',
  },
  endedCard: {
    backgroundColor: 'rgba(255,255,255,0.72)',
  },
  eventHeader: {
    alignItems: 'flex-start',
    flexDirection: 'row',
    gap: spacing.md,
  },
  timeColumn: {
    alignItems: 'center',
    backgroundColor: colors.surfaceSoft,
    borderRadius: radii.md,
    minWidth: 74,
    paddingHorizontal: spacing.sm,
    paddingVertical: spacing.md,
  },
  timeText: {
    color: colors.primary,
    fontSize: 19,
    fontWeight: '900',
  },
  timeRange: {
    color: colors.subtext,
    fontSize: 11,
    fontWeight: '700',
    marginTop: 3,
  },
  eventMain: {
    flex: 1,
    gap: spacing.sm,
    minWidth: 0,
  },
  statusRow: {
    alignItems: 'center',
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: spacing.sm,
  },
  startGuide: {
    color: colors.subtext,
    fontSize: 12,
    fontWeight: '700',
  },
  eventTitle: {
    color: colors.text,
    fontSize: 17,
    fontWeight: '800',
    lineHeight: 24,
  },
  metaWrap: {
    gap: 4,
  },
  metaRow: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: spacing.xs,
  },
  metaText: {
    color: colors.subtext,
    flexShrink: 1,
    fontSize: 12,
    lineHeight: 18,
  },
  checkBlock: {
    borderTopColor: colors.border,
    borderTopWidth: StyleSheet.hairlineWidth,
    gap: spacing.sm,
    paddingTop: spacing.md,
  },
  checkLabel: {
    color: colors.primary,
    fontSize: 12,
    fontWeight: '800',
  },
  description: {
    color: colors.text,
    fontSize: 13,
    lineHeight: 20,
  },
  checkList: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: spacing.sm,
  },
  checkPill: {
    backgroundColor: colors.surfaceSoft,
    borderRadius: radii.pill,
    paddingHorizontal: spacing.md,
    paddingVertical: 6,
  },
  checkPillText: {
    color: colors.subtext,
    fontSize: 12,
    fontWeight: '700',
  },
  dimText: {
    color: colors.subtext,
  },
  emptyText: {
    color: colors.subtext,
    fontSize: 14,
    lineHeight: 21,
    padding: spacing.xl,
    textAlign: 'center',
  },
  sheetLayer: {
    ...StyleSheet.absoluteFillObject,
    justifyContent: 'flex-end',
    zIndex: 80,
  },
  backdrop: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: colors.overlay,
  },
  sheet: {
    backgroundColor: colors.surface,
    borderTopLeftRadius: radii.xl,
    borderTopRightRadius: radii.xl,
    maxHeight: '72%',
    paddingBottom: spacing.xl,
    paddingHorizontal: spacing.lg,
  },
  handle: {
    alignSelf: 'center',
    backgroundColor: colors.border,
    borderRadius: radii.pill,
    height: 4,
    marginVertical: spacing.md,
    width: 40,
  },
  sheetHeader: {
    alignItems: 'flex-start',
    flexDirection: 'row',
    gap: spacing.md,
  },
  sheetText: {
    flex: 1,
    gap: spacing.sm,
  },
  sheetTitle: {
    color: colors.text,
    fontSize: 21,
    fontWeight: '900',
    lineHeight: 29,
  },
  sheetMeta: {
    color: colors.subtext,
    fontSize: 13,
    lineHeight: 19,
  },
  closeButton: {
    alignItems: 'center',
    borderRadius: radii.pill,
    height: 40,
    justifyContent: 'center',
    width: 40,
  },
  tagRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: spacing.sm,
    marginTop: spacing.lg,
  },
  primaryTag: {
    backgroundColor: 'rgba(11, 58, 103, 0.1)',
    borderRadius: radii.pill,
    color: colors.primary,
    fontSize: 12,
    fontWeight: '800',
    paddingHorizontal: spacing.md,
    paddingVertical: 6,
  },
  neutralTag: {
    backgroundColor: colors.surfaceSoft,
    borderRadius: radii.pill,
    color: colors.subtext,
    fontSize: 12,
    fontWeight: '700',
    paddingHorizontal: spacing.md,
    paddingVertical: 6,
  },
  sheetDescription: {
    color: colors.text,
    fontSize: 14,
    lineHeight: 22,
    marginTop: spacing.lg,
  },
  sheetCheckSection: {
    gap: spacing.sm,
    marginTop: spacing.lg,
  },
  sheetSectionTitle: {
    color: colors.primary,
    fontSize: 13,
    fontWeight: '900',
  },
  sheetCheckRow: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: spacing.sm,
  },
  sheetCheckText: {
    color: colors.text,
    flex: 1,
    fontSize: 13,
    lineHeight: 19,
  },
  mapButton: {
    alignItems: 'center',
    backgroundColor: colors.primary,
    borderRadius: radii.md,
    flexDirection: 'row',
    gap: spacing.sm,
    justifyContent: 'center',
    marginTop: spacing.xl,
    minHeight: 48,
  },
  mapButtonText: {
    color: colors.primaryForeground,
    fontSize: 14,
    fontWeight: '900',
  },
  pressed: {
    opacity: 0.78,
  },
});
