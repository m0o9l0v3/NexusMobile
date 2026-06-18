import { StyleSheet, Text, View } from 'react-native';
import { colors, spacing, typography } from '../../theme/tokens';
import { AppIcon } from '../icons/AppIcon';

type SectionHeaderProps = {
  title: string;
  caption?: string;
  icon?: Parameters<typeof AppIcon>[0]['name'];
};

export function SectionHeader({ title, caption, icon }: SectionHeaderProps) {
  return (
    <View style={styles.wrap}>
      <View style={styles.titleRow}>
        {icon ? <AppIcon name={icon} size={18} color={colors.primary} /> : null}
        <Text style={typography.sectionTitle}>{title}</Text>
      </View>
      {caption ? <Text style={styles.caption}>{caption}</Text> : null}
    </View>
  );
}

const styles = StyleSheet.create({
  wrap: {
    gap: spacing.xs,
  },
  titleRow: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: spacing.sm,
  },
  caption: {
    color: colors.subtext,
    fontSize: 13,
    lineHeight: 19,
  },
});
