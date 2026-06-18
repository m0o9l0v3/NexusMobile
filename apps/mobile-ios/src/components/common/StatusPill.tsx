import { StyleSheet, Text, View } from 'react-native';
import type { EventStatus } from '../../data/openCampus';
import { colors, radii, spacing } from '../../theme/tokens';

type StatusPillProps = {
  label: string;
  status?: EventStatus;
};

const toneByStatus: Record<EventStatus, { bg: string; text: string; dot: string }> = {
  live: { bg: 'rgba(11, 58, 103, 0.1)', text: colors.primary, dot: colors.primary },
  next: { bg: 'rgba(26, 115, 232, 0.1)', text: colors.accent, dot: colors.accent },
  upcoming: { bg: colors.surfaceSoft, text: colors.subtext, dot: colors.muted },
  ended: { bg: 'rgba(154, 166, 184, 0.16)', text: colors.subtext, dot: colors.muted },
};

export function StatusPill({ label, status = 'upcoming' }: StatusPillProps) {
  const tone = toneByStatus[status];
  return (
    <View style={[styles.pill, { backgroundColor: tone.bg }]}>
      <View style={[styles.dot, { backgroundColor: tone.dot }]} />
      <Text style={[styles.text, { color: tone.text }]}>{label}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  pill: {
    alignItems: 'center',
    alignSelf: 'flex-start',
    borderRadius: radii.pill,
    flexDirection: 'row',
    gap: spacing.xs,
    paddingHorizontal: spacing.md,
    paddingVertical: 5,
  },
  dot: {
    borderRadius: 4,
    height: 7,
    width: 7,
  },
  text: {
    fontSize: 12,
    fontWeight: '700',
  },
});
