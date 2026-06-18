import { useMemo, useState } from 'react';
import { Pressable, SafeAreaView, ScrollView, StyleSheet, Text, TextInput, View } from 'react-native';
import { colors, radii, spacing, typography } from '../../theme/tokens';
import type { MapSpot } from '../../types/navigation';
import { AppIcon } from '../icons/AppIcon';
import { SuggestListItem } from './SuggestListItem';

type MapSearchOverlayProps = {
  isOpen: boolean;
  spots: MapSpot[];
  onClose: () => void;
  onSelectSpot: (spot: MapSpot) => void;
};

export function MapSearchOverlay({ isOpen, spots, onClose, onSelectSpot }: MapSearchOverlayProps) {
  const [query, setQuery] = useState('');
  const filteredSpots = useMemo(() => {
    const normalized = query.trim().toLowerCase();
    if (!normalized) {
      return spots.filter((spot) => spot.kind !== 'current').slice(0, 6);
    }

    return spots.filter((spot) => {
      return `${spot.name} ${spot.category} ${spot.floor} ${spot.tags?.join(' ') ?? ''}`.toLowerCase().includes(normalized);
    });
  }, [query, spots]);

  if (!isOpen) {
    return null;
  }

  return (
    <SafeAreaView style={styles.overlay}>
      <View style={styles.header}>
        <Pressable onPress={onClose} style={styles.iconButton}>
          <AppIcon name="x" size={20} color={colors.text} />
        </Pressable>
        <Text style={typography.sectionTitle}>検索</Text>
      </View>

      <View style={styles.inputWrap}>
        <AppIcon name="search" size={18} color={colors.accent} />
        <TextInput
          autoFocus
          placeholder="場所・教室・イベントを検索"
          placeholderTextColor={colors.subtext}
          value={query}
          onChangeText={setQuery}
          style={styles.input}
        />
      </View>

      <ScrollView contentContainerStyle={styles.results} showsVerticalScrollIndicator={false}>
        {filteredSpots.map((spot) => (
          <SuggestListItem
            key={spot.id}
            spot={spot}
            onPress={() => {
              onSelectSpot(spot);
              onClose();
            }}
          />
        ))}
        {filteredSpots.length === 0 ? <Text style={styles.empty}>見つからない場合は受付でご確認ください。</Text> : null}
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  overlay: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: colors.background,
    zIndex: 90,
  },
  header: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: spacing.md,
    paddingHorizontal: spacing.lg,
    paddingVertical: spacing.md,
  },
  iconButton: {
    alignItems: 'center',
    borderRadius: radii.pill,
    height: 40,
    justifyContent: 'center',
    width: 40,
  },
  inputWrap: {
    alignItems: 'center',
    backgroundColor: colors.surface,
    borderColor: colors.border,
    borderRadius: radii.pill,
    borderWidth: StyleSheet.hairlineWidth,
    flexDirection: 'row',
    gap: spacing.sm,
    marginHorizontal: spacing.lg,
    paddingHorizontal: spacing.md,
    paddingVertical: 4,
  },
  input: {
    color: colors.text,
    flex: 1,
    fontSize: 16,
    minHeight: 44,
  },
  results: {
    paddingHorizontal: spacing.lg,
    paddingTop: spacing.md,
  },
  empty: {
    color: colors.subtext,
    fontSize: 14,
    paddingVertical: spacing.xl,
    textAlign: 'center',
  },
});
