import { router } from 'expo-router';
import { Pressable, SafeAreaView, ScrollView, StyleSheet, Text, View } from 'react-native';
import {
  checkItems,
  getEventStatus,
  getFeaturedEvent,
  getSpotNameForEvent,
  getStartGuide,
  getStatusLabel,
} from '../data/openCampus';
import { colors, radii, spacing, typography } from '../theme/tokens';
import type { CampusEvent } from '../types/events';
import { BottomNav } from './BottomNav';
import { AppCard } from './common/AppCard';
import { SectionHeader } from './common/SectionHeader';
import { StatusPill } from './common/StatusPill';
import { AppIcon } from './icons/AppIcon';

type HomeScreenProps = {
  events: CampusEvent[];
};

const quickAccessItems = [
  { type: 'href', label: 'マップ', caption: '会場を確認', icon: 'map' as const, href: '/map' as const },
  { type: 'href', label: 'イベント', caption: '予定を見る', icon: 'calendar' as const, href: '/events' as const },
  { type: 'spot', label: '受付', caption: '困ったらここへ', icon: 'mapPin' as const, spotName: '受付' },
  { type: 'event', label: '保護者向け相談', caption: '生活・進路を確認', icon: 'users' as const, eventId: 'parent-consultation' },
  { type: 'spot', label: '困ったとき', caption: 'スタッフに相談', icon: 'helpCircle' as const, spotName: '受付' },
] as const;

export function HomeScreen({ events }: HomeScreenProps) {
  const guideEvent = getFeaturedEvent(events);
  const guideStatus = guideEvent ? getEventStatus(guideEvent, events) : 'upcoming';

  const openMapForEvent = (event: CampusEvent) => {
    router.push({ pathname: '/map', params: { spotName: getSpotNameForEvent(event) } });
  };

  const openEventDetail = (event: CampusEvent) => {
    router.push({ pathname: '/events', params: { eventId: event.id } });
  };

  return (
    <View style={styles.root}>
      <SafeAreaView style={styles.safeArea}>
        <ScrollView contentContainerStyle={styles.scrollContent} showsVerticalScrollIndicator={false}>
          <View style={styles.header}>
            <View style={styles.brandRow}>
              <View style={styles.brandMark}>
                <AppIcon name="plane" size={22} color={colors.primary} />
              </View>
              <View style={styles.brandText}>
                <Text style={styles.kicker}>本日のオープンキャンパス案内</Text>
                <Text style={styles.title}>日本航空学園 北海道キャンパス</Text>
              </View>
            </View>
            <Text style={styles.headerCopy}>次に向かう場所と、今日確認してほしいことをまとめています。</Text>
          </View>

          <View style={styles.section}>
            <SectionHeader title="今日の案内" caption="まずは次の予定と場所を確認してください。" icon="clock" />
            <AppCard accent style={styles.guideCard}>
              {guideEvent ? (
                <>
                  <View style={styles.guideTop}>
                    <StatusPill label={getStatusLabel(guideStatus)} status={guideStatus} />
                    <Text style={styles.startGuide}>{getStartGuide(guideEvent)}</Text>
                  </View>
                  <View style={styles.guideMain}>
                    <View style={styles.timeBlock}>
                      <Text style={styles.timeText}>{guideEvent.time}</Text>
                      <Text style={styles.timeSub}>開始</Text>
                    </View>
                    <View style={styles.guideBody}>
                      <Text style={styles.guideTitle}>{guideEvent.title}</Text>
                      <View style={styles.metaRow}>
                        <AppIcon name="mapPin" size={14} color={colors.subtext} />
                        <Text style={styles.metaText}>
                          {guideEvent.location}
                          {guideEvent.floor ? ` / ${guideEvent.floor}` : ''}
                        </Text>
                      </View>
                      <Text style={styles.guideDescription} numberOfLines={2}>
                        {guideEvent.description}
                      </Text>
                    </View>
                  </View>
                  <View style={styles.actionRow}>
                    <Pressable onPress={() => openMapForEvent(guideEvent)} style={({ pressed }) => [styles.secondaryButton, pressed && styles.pressed]}>
                      <AppIcon name="map" size={16} color={colors.primary} />
                      <Text style={styles.secondaryButtonText}>場所を見る</Text>
                    </Pressable>
                    <Pressable onPress={() => openEventDetail(guideEvent)} style={({ pressed }) => [styles.primaryButton, pressed && styles.pressed]}>
                      <Text style={styles.primaryButtonText}>イベント詳細</Text>
                      <AppIcon name="arrowRight" size={16} color={colors.primaryForeground} />
                    </Pressable>
                  </View>
                </>
              ) : (
                <View style={styles.emptyGuide}>
                  <Text style={styles.guideTitle}>受付で本日の流れをご確認ください</Text>
                  <Text style={styles.guideDescription}>スタッフが次の行き先をご案内します。</Text>
                </View>
              )}
            </AppCard>
          </View>

          <View style={styles.section}>
            <SectionHeader title="今日確認してほしいこと" caption="進路選択に必要な観点を、短い時間でも見落とさないためのチェックです。" icon="check" />
            <View style={styles.checkGrid}>
              {checkItems.map((item) => (
                <View key={item} style={styles.checkChip}>
                  <AppIcon name="check" size={13} color={colors.accent} strokeWidth={2.4} />
                  <Text style={styles.checkText}>{item}</Text>
                </View>
              ))}
            </View>
          </View>

          <View style={styles.section}>
            <SectionHeader title="クイックアクセス" caption="迷ったときにすぐ開ける導線です。" icon="navigation" />
            <View style={styles.quickGrid}>
              {quickAccessItems.map((item) => (
                <Pressable
                  key={item.label}
                  onPress={() => {
                    if (item.type === 'href') {
                      router.push(item.href);
                    } else if (item.type === 'event') {
                      router.push({ pathname: '/events', params: { eventId: item.eventId } });
                    } else {
                      router.push({ pathname: '/map', params: { spotName: item.spotName } });
                    }
                  }}
                  style={({ pressed }) => [
                    styles.quickCard,
                    item.label === '保護者向け相談' && styles.parentQuickCard,
                    pressed && styles.pressed,
                  ]}
                >
                  <View style={styles.quickIcon}>
                    <AppIcon name={item.icon} size={19} color={item.label === '保護者向け相談' ? colors.primary : colors.accent} />
                  </View>
                  <View style={styles.quickBody}>
                    <Text style={styles.quickTitle}>{item.label}</Text>
                    <Text style={styles.quickCaption}>{item.caption}</Text>
                  </View>
                  <AppIcon name="chevronRight" size={16} color={colors.muted} />
                </Pressable>
              ))}
            </View>
          </View>

          <Pressable
            onPress={() => router.push({ pathname: '/map', params: { spotName: '受付' } })}
            style={({ pressed }) => [styles.helpBanner, pressed && styles.pressed]}
          >
            <AppIcon name="shield" size={18} color={colors.primary} />
            <Text style={styles.helpText}>困ったときは受付・近くのスタッフへお声がけください。</Text>
            <AppIcon name="arrowRight" size={15} color={colors.primary} />
          </Pressable>
        </ScrollView>
      </SafeAreaView>
      <BottomNav />
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
  scrollContent: {
    paddingBottom: 112,
  },
  header: {
    backgroundColor: colors.surface,
    borderBottomColor: colors.border,
    borderBottomWidth: StyleSheet.hairlineWidth,
    gap: spacing.md,
    paddingBottom: spacing.xl,
    paddingHorizontal: spacing.lg,
    paddingTop: spacing.xl,
  },
  brandRow: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: spacing.md,
  },
  brandMark: {
    alignItems: 'center',
    backgroundColor: colors.surfaceSoft,
    borderColor: colors.border,
    borderRadius: radii.lg,
    borderWidth: StyleSheet.hairlineWidth,
    height: 46,
    justifyContent: 'center',
    width: 46,
  },
  brandText: {
    flex: 1,
    gap: 2,
  },
  kicker: {
    color: colors.accent,
    fontSize: 12,
    fontWeight: '700',
  },
  title: {
    ...typography.title,
    fontSize: 23,
  },
  headerCopy: {
    color: colors.subtext,
    fontSize: 14,
    lineHeight: 21,
  },
  section: {
    gap: spacing.md,
    paddingHorizontal: spacing.lg,
    paddingTop: spacing.xl,
  },
  guideCard: {
    gap: spacing.lg,
  },
  guideTop: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: spacing.md,
    justifyContent: 'space-between',
  },
  startGuide: {
    color: colors.primary,
    flexShrink: 1,
    fontSize: 13,
    fontWeight: '700',
    textAlign: 'right',
  },
  guideMain: {
    alignItems: 'flex-start',
    flexDirection: 'row',
    gap: spacing.md,
  },
  timeBlock: {
    alignItems: 'center',
    backgroundColor: colors.primary,
    borderRadius: radii.md,
    minWidth: 70,
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.md,
  },
  timeText: {
    color: colors.primaryForeground,
    fontSize: 18,
    fontWeight: '800',
  },
  timeSub: {
    color: 'rgba(255,255,255,0.78)',
    fontSize: 11,
    fontWeight: '700',
    marginTop: 2,
  },
  guideBody: {
    flex: 1,
    gap: spacing.sm,
    minWidth: 0,
  },
  guideTitle: {
    color: colors.text,
    fontSize: 19,
    fontWeight: '800',
    lineHeight: 26,
  },
  metaRow: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: spacing.xs,
  },
  metaText: {
    color: colors.subtext,
    flexShrink: 1,
    fontSize: 13,
    lineHeight: 19,
  },
  guideDescription: {
    color: colors.subtext,
    fontSize: 13,
    lineHeight: 19,
  },
  actionRow: {
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
    minHeight: 46,
    paddingHorizontal: spacing.md,
  },
  primaryButtonText: {
    color: colors.primaryForeground,
    fontSize: 14,
    fontWeight: '800',
  },
  secondaryButton: {
    alignItems: 'center',
    backgroundColor: colors.surfaceSoft,
    borderColor: colors.border,
    borderRadius: radii.md,
    borderWidth: StyleSheet.hairlineWidth,
    flex: 1,
    flexDirection: 'row',
    gap: spacing.sm,
    justifyContent: 'center',
    minHeight: 46,
    paddingHorizontal: spacing.md,
  },
  secondaryButtonText: {
    color: colors.primary,
    fontSize: 14,
    fontWeight: '800',
  },
  emptyGuide: {
    gap: spacing.sm,
  },
  checkGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: spacing.sm,
  },
  checkChip: {
    alignItems: 'center',
    backgroundColor: colors.surface,
    borderColor: colors.border,
    borderRadius: radii.pill,
    borderWidth: StyleSheet.hairlineWidth,
    flexDirection: 'row',
    gap: spacing.xs,
    paddingHorizontal: spacing.md,
    paddingVertical: 9,
  },
  checkText: {
    color: colors.text,
    fontSize: 13,
    fontWeight: '700',
  },
  quickGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: spacing.md,
  },
  quickCard: {
    alignItems: 'center',
    backgroundColor: colors.surface,
    borderColor: colors.border,
    borderRadius: radii.lg,
    borderWidth: StyleSheet.hairlineWidth,
    flexBasis: '47%',
    flexDirection: 'row',
    gap: spacing.sm,
    minHeight: 78,
    padding: spacing.md,
  },
  parentQuickCard: {
    backgroundColor: colors.surfaceSoft,
    borderColor: 'rgba(11, 58, 103, 0.18)',
  },
  quickIcon: {
    alignItems: 'center',
    backgroundColor: colors.background,
    borderRadius: radii.md,
    height: 36,
    justifyContent: 'center',
    width: 36,
  },
  quickBody: {
    flex: 1,
    gap: 2,
    minWidth: 0,
  },
  quickTitle: {
    color: colors.text,
    fontSize: 13,
    fontWeight: '800',
    lineHeight: 18,
  },
  quickCaption: {
    color: colors.subtext,
    fontSize: 11,
    lineHeight: 16,
  },
  helpBanner: {
    alignItems: 'center',
    backgroundColor: colors.surfaceSoft,
    borderColor: colors.border,
    borderRadius: radii.lg,
    borderWidth: StyleSheet.hairlineWidth,
    flexDirection: 'row',
    gap: spacing.sm,
    marginHorizontal: spacing.lg,
    marginTop: spacing.xl,
    padding: spacing.lg,
  },
  helpText: {
    color: colors.primary,
    flex: 1,
    fontSize: 13,
    fontWeight: '700',
    lineHeight: 19,
  },
  pressed: {
    opacity: 0.78,
  },
});
