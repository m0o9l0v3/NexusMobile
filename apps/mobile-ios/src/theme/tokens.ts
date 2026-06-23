import { StyleSheet } from 'react-native';

export const theme = {
  name: 'Northern Aviation Blue',
  colors: {
    primary: '#0B3A67',
    accent: '#1A73E8',
    sky: '#DFF3FF',
    background: '#F6FAFC',
    surface: '#FFFFFF',
    surfaceSoft: '#EEF7FC',
    text: '#071A36',
    subtext: '#6B768A',
    muted: '#9AA6B8',
    success: '#1F9D63',
    warning: '#F59E0B',
    danger: '#D92D20',
    border: 'rgba(7, 26, 54, 0.08)',
    shadow: 'rgba(7, 26, 54, 0.12)',
    overlay: 'rgba(7, 26, 54, 0.32)',
  },
};

export const colors = {
  ...theme.colors,
  sky0: theme.colors.background,
  sky1: theme.colors.sky,
  sky2: '#B9E4FA',
  floatingSurface: 'rgba(255, 255, 255, 0.94)',
  mapBackground: '#EAF2F6',
  mapBuilding: '#D9E2E8',
  mapRoom: '#FFFFFF',
  mapPath: '#F4F7F9',
  mapLabel: '#5D6B7C',
  primarySoft: 'rgba(11, 58, 103, 0.10)',
  accentSoft: 'rgba(26, 115, 232, 0.10)',
  successSoft: 'rgba(31, 157, 99, 0.10)',
  primaryWeak: theme.colors.surfaceSoft,
  primaryForeground: '#FFFFFF',
  mutedForeground: theme.colors.subtext,
  outline: theme.colors.border,
  empty: theme.colors.success,
  normal: theme.colors.accent,
  busy: theme.colors.warning,
  full: theme.colors.danger,
};

export const spacing = {
  xs: 4,
  sm: 8,
  md: 12,
  lg: 16,
  xl: 24,
  xxl: 32,
};

export const radii = {
  sm: 8,
  md: 10,
  lg: 14,
  xl: 20,
  pill: 999,
};

export const typography = StyleSheet.create({
  title: {
    color: colors.text,
    fontSize: 24,
    fontWeight: '700',
    lineHeight: 32,
  },
  sectionTitle: {
    color: colors.text,
    fontSize: 18,
    fontWeight: '700',
    lineHeight: 26,
  },
  body: {
    color: colors.text,
    fontSize: 14,
    lineHeight: 21,
  },
  caption: {
    color: colors.mutedForeground,
    fontSize: 12,
    lineHeight: 18,
  },
});

export const shadows = StyleSheet.create({
  level1: {
    shadowColor: colors.shadow,
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.08,
    shadowRadius: 4,
    elevation: 1,
  },
  level2: {
    shadowColor: colors.shadow,
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 10,
    elevation: 3,
  },
  level3: {
    shadowColor: colors.shadow,
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.12,
    shadowRadius: 16,
    elevation: 6,
  },
});
