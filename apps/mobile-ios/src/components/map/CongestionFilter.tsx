import { Pressable, StyleSheet, Text, View } from 'react-native';
import { colors, radii, shadows, spacing } from '../../theme/tokens';
import { congestionLabels, type CongestionLevel } from '../../types/navigation';
import { CongestionBadge } from '../CongestionBadge';

type CongestionFilterProps = {
  isOpen: boolean;
  selectedLevels: CongestionLevel[];
  onLevelToggle: (level: CongestionLevel) => void;
  onClear: () => void;
};

const levels: CongestionLevel[] = ['empty', 'normal', 'busy', 'full'];

export function CongestionFilter({ isOpen, selectedLevels, onLevelToggle, onClear }: CongestionFilterProps) {
  if (!isOpen) {
    return null;
  }

  return (
    <View style={styles.menu}>
      <View style={styles.header}>
        <Text style={styles.title}>混雑状況</Text>
        <Pressable onPress={onClear}>
          <Text style={styles.clear}>解除</Text>
        </Pressable>
      </View>
      {levels.map((level) => {
        const selected = selectedLevels.includes(level);
        return (
          <Pressable
            key={level}
            onPress={() => onLevelToggle(level)}
            style={[styles.row, selected && styles.selectedRow]}
          >
            <CongestionBadge level={level} compact />
            <Text style={[styles.rowText, selected && styles.selectedText]}>{congestionLabels[level]}</Text>
          </Pressable>
        );
      })}
    </View>
  );
}

const styles = StyleSheet.create({
  menu: {
    backgroundColor: colors.surface,
    borderRadius: radii.lg,
    marginTop: spacing.sm,
    padding: spacing.md,
    position: 'absolute',
    right: 0,
    top: 48,
    width: 196,
    ...shadows.level2,
  },
  header: {
    alignItems: 'center',
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: spacing.sm,
  },
  title: {
    color: colors.text,
    fontSize: 12,
    fontWeight: '700',
  },
  clear: {
    color: colors.primary,
    fontSize: 12,
    fontWeight: '700',
  },
  row: {
    alignItems: 'center',
    borderRadius: radii.md,
    flexDirection: 'row',
    gap: spacing.sm,
    padding: spacing.sm,
  },
  selectedRow: {
    backgroundColor: colors.muted,
  },
  rowText: {
    color: colors.text,
    fontSize: 12,
  },
  selectedText: {
    color: colors.primary,
    fontWeight: '700',
  },
});
