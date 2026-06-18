import { useMemo, useState } from 'react';
import { Pressable, SafeAreaView, ScrollView, StyleSheet, Text, View } from 'react-native';
import { colors, radii, shadows, spacing, typography } from '../theme/tokens';
import type { CampusEvent } from '../types/events';
import { BottomNav } from './BottomNav';
import { AppIcon } from './icons/AppIcon';

type EventsScreenProps = {
  events: CampusEvent[];
  initialEventId?: string;
};

const categories = ['すべて', '説明会', 'ツアー', '模擬授業', '相談会', 'イベント'];
const departments = ['全体', '工学部', '情報学部', '理学部', '医学部'];

export function EventsScreen({ events, initialEventId }: EventsScreenProps) {
  const [selectedCategory, setSelectedCategory] = useState('すべて');
  const [selectedDepartment, setSelectedDepartment] = useState('全体');
  const [isDepartmentFilterOpen, setIsDepartmentFilterOpen] = useState(false);
  const [selectedEvent, setSelectedEvent] = useState<CampusEvent | undefined>(
    events.find((event) => event.id === initialEventId),
  );

  const filteredEvents = useMemo(
    () =>
      events.filter((event) => {
        if (selectedCategory !== 'すべて' && event.category !== selectedCategory) return false;
        if (selectedDepartment !== '全体' && event.department !== selectedDepartment) return false;
        return true;
      }),
    [events, selectedCategory, selectedDepartment],
  );

  const groupedEvents = useMemo(() => {
    return filteredEvents.reduce<Record<string, CampusEvent[]>>((acc, event) => {
      const hour = event.time.split(':')[0] ?? '--';
      acc[hour] = [...(acc[hour] ?? []), event];
      return acc;
    }, {});
  }, [filteredEvents]);

  return (
    <View style={styles.root}>
      <SafeAreaView style={styles.safeArea}>
        <View style={styles.header}>
          <Text style={typography.title}>イベント</Text>
          <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.chipRow}>
            {categories.map((category) => (
              <Pressable
                key={category}
                onPress={() => setSelectedCategory(category)}
                style={[styles.chip, selectedCategory === category && styles.activeChip]}
              >
                <Text style={[styles.chipText, selectedCategory === category && styles.activeChipText]}>{category}</Text>
              </Pressable>
            ))}
          </ScrollView>
        </View>

        <View style={styles.filterWrap}>
          <Pressable
            accessibilityRole="button"
            onPress={() => setIsDepartmentFilterOpen((value) => !value)}
            style={styles.filterButton}
          >
            <AppIcon name="filter" size={20} color={isDepartmentFilterOpen ? colors.primary : colors.text} />
          </Pressable>
          {isDepartmentFilterOpen ? (
            <View style={styles.departmentMenu}>
              <Text style={styles.menuTitle}>学部フィルタ</Text>
              {departments.map((department) => (
                <Pressable
                  key={department}
                  onPress={() => {
                    setSelectedDepartment(department);
                    setIsDepartmentFilterOpen(false);
                  }}
                  style={[styles.menuItem, selectedDepartment === department && styles.activeMenuItem]}
                >
                  <Text style={[styles.menuText, selectedDepartment === department && styles.activeMenuText]}>{department}</Text>
                </Pressable>
              ))}
            </View>
          ) : null}
        </View>

        <ScrollView contentContainerStyle={styles.timelineContent} showsVerticalScrollIndicator={false}>
          {Object.keys(groupedEvents).sort().map((hour) => (
            <View key={hour} style={styles.hourGroup}>
              <View style={styles.hourHeader}>
                <Text style={styles.hourPill}>{hour}:00</Text>
                <View style={styles.hourLine} />
              </View>

              <View style={styles.stack}>
                {groupedEvents[hour].map((event) => (
                  <View key={event.id} style={styles.eventCard}>
                    <Pressable onPress={() => setSelectedEvent(event)} style={({ pressed }) => [pressed && styles.pressed]}>
                      <View style={styles.eventRow}>
                        <View style={styles.bullet} />
                        <View style={styles.eventBody}>
                          <View style={styles.eventTitleRow}>
                            <Text style={styles.eventTitle}>{event.title}</Text>
                            <Text style={styles.departmentPill}>{event.department}</Text>
                          </View>
                          <View style={styles.metaWrap}>
                            <View style={styles.metaRow}>
                              <AppIcon name="clock" size={12} color={colors.mutedForeground} />
                              <Text style={styles.metaText}>{event.time} - {event.endTime ?? '--:--'}</Text>
                            </View>
                            <View style={styles.metaRow}>
                              <AppIcon name="mapPin" size={12} color={colors.mutedForeground} />
                              <Text style={styles.metaText}>{event.location}{event.floor ? ` (${event.floor})` : ''}</Text>
                            </View>
                          </View>
                          {event.description ? <Text style={styles.description}>{event.description}</Text> : null}
                        </View>
                      </View>
                    </Pressable>
                  </View>
                ))}
              </View>
            </View>
          ))}
        </ScrollView>
      </SafeAreaView>

      {selectedEvent ? <EventDetailSheet event={selectedEvent} onClose={() => setSelectedEvent(undefined)} /> : null}
      <BottomNav />
    </View>
  );
}

function EventDetailSheet({ event, onClose }: { event: CampusEvent; onClose: () => void }) {
  return (
    <View style={styles.sheetLayer}>
      <Pressable style={styles.backdrop} onPress={onClose} />
      <View style={styles.sheet}>
        <View style={styles.handle} />
        <View style={styles.sheetHeader}>
          <View style={styles.sheetText}>
            <Text style={styles.sheetTitle}>{event.title}</Text>
            <Text style={styles.sheetMeta}>{event.time} - {event.endTime ?? '--:--'}</Text>
            <Text style={styles.sheetMeta}>{event.location}{event.floor ? ` / ${event.floor}` : ''}</Text>
          </View>
          <Pressable onPress={onClose} style={styles.closeButton}>
            <AppIcon name="x" size={20} color={colors.text} />
          </Pressable>
        </View>
        <View style={styles.tagRow}>
          <Text style={styles.primaryTag}>{event.department}</Text>
          {event.category ? <Text style={styles.neutralTag}>{event.category}</Text> : null}
        </View>
        {event.description ? <Text style={styles.sheetDescription}>{event.description}</Text> : null}
      </View>
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
  header: {
    backgroundColor: colors.surface,
    borderBottomColor: colors.outline,
    borderBottomWidth: StyleSheet.hairlineWidth,
    paddingHorizontal: spacing.lg,
    paddingTop: spacing.lg,
  },
  chipRow: {
    gap: spacing.sm,
    paddingVertical: spacing.md,
  },
  chip: {
    backgroundColor: colors.muted,
    borderRadius: radii.pill,
    paddingHorizontal: spacing.md,
    paddingVertical: 7,
  },
  activeChip: {
    backgroundColor: colors.primary,
  },
  chipText: {
    color: colors.text,
    fontSize: 12,
    fontWeight: '600',
  },
  activeChipText: {
    color: colors.primaryForeground,
  },
  filterWrap: {
    position: 'absolute',
    right: spacing.lg,
    top: 130,
    zIndex: 20,
  },
  filterButton: {
    alignItems: 'center',
    backgroundColor: colors.surface,
    borderRadius: radii.pill,
    height: 48,
    justifyContent: 'center',
    width: 48,
    ...shadows.level2,
  },
  departmentMenu: {
    backgroundColor: colors.surface,
    borderRadius: radii.lg,
    marginTop: spacing.sm,
    padding: spacing.md,
    position: 'absolute',
    right: 0,
    top: 48,
    width: 200,
    ...shadows.level2,
  },
  menuTitle: {
    color: colors.text,
    fontSize: 12,
    fontWeight: '700',
    marginBottom: spacing.sm,
  },
  menuItem: {
    borderRadius: radii.sm,
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm,
  },
  activeMenuItem: {
    backgroundColor: colors.primaryWeak,
  },
  menuText: {
    color: colors.text,
    fontSize: 12,
  },
  activeMenuText: {
    color: colors.primary,
    fontWeight: '700',
  },
  timelineContent: {
    paddingBottom: 112,
  },
  hourGroup: {
    paddingHorizontal: spacing.lg,
    paddingTop: spacing.lg,
  },
  hourHeader: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: spacing.md,
    marginBottom: spacing.md,
  },
  hourPill: {
    backgroundColor: colors.muted,
    borderRadius: radii.pill,
    color: colors.text,
    fontSize: 14,
    fontWeight: '700',
    paddingHorizontal: spacing.md,
    paddingVertical: 5,
  },
  hourLine: {
    backgroundColor: colors.outline,
    flex: 1,
    height: StyleSheet.hairlineWidth,
  },
  stack: {
    gap: spacing.md,
  },
  eventCard: {
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
  bullet: {
    backgroundColor: colors.primary,
    borderRadius: 4,
    height: 8,
    marginTop: 7,
    width: 8,
  },
  eventBody: {
    flex: 1,
    gap: spacing.sm,
  },
  eventTitleRow: {
    alignItems: 'flex-start',
    flexDirection: 'row',
    gap: spacing.sm,
    justifyContent: 'space-between',
  },
  eventTitle: {
    color: colors.text,
    flex: 1,
    fontSize: 16,
    fontWeight: '600',
    lineHeight: 22,
  },
  departmentPill: {
    backgroundColor: colors.muted,
    borderRadius: radii.sm,
    color: colors.mutedForeground,
    fontSize: 10,
    fontWeight: '700',
    paddingHorizontal: spacing.sm,
    paddingVertical: 3,
  },
  metaWrap: {
    gap: 4,
  },
  metaRow: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: 5,
  },
  metaText: {
    color: colors.mutedForeground,
    flexShrink: 1,
    fontSize: 12,
  },
  description: {
    color: colors.mutedForeground,
    fontSize: 13,
    lineHeight: 19,
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
    maxHeight: '62%',
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
    fontSize: 18,
    fontWeight: '700',
    lineHeight: 26,
  },
  sheetMeta: {
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
  tagRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: spacing.sm,
    marginTop: spacing.lg,
  },
  primaryTag: {
    backgroundColor: colors.primaryWeak,
    borderRadius: radii.sm,
    color: colors.primary,
    fontSize: 12,
    fontWeight: '700',
    paddingHorizontal: spacing.sm,
    paddingVertical: 5,
  },
  neutralTag: {
    backgroundColor: colors.muted,
    borderRadius: radii.sm,
    color: colors.text,
    fontSize: 12,
    fontWeight: '600',
    paddingHorizontal: spacing.sm,
    paddingVertical: 5,
  },
  sheetDescription: {
    color: colors.text,
    fontSize: 14,
    lineHeight: 21,
    marginTop: spacing.lg,
  },
});
