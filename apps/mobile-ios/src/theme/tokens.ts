import { StyleSheet } from 'react-native';

export const colors = {
  sky0: '#F4FBFF',
  sky1: '#DDF1FF',
  sky2: '#A7D8FF',
  primary: '#0B5ED7',
  primaryWeak: '#A7D8FF',
  primaryForeground: '#FFFFFF',
  text: '#0B1B3A',
  surface: '#FFFFFF',
  muted: '#F4FBFF',
  mutedForeground: 'rgba(11, 27, 58, 0.6)',
  outline: 'rgba(11, 27, 58, 0.12)',
  empty: '#34A853',
  normal: '#FBBC04',
  busy: '#FF9800',
  full: '#EA4335',
  overlay: 'rgba(11, 27, 58, 0.22)',
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
  md: 12,
  lg: 16,
  xl: 24,
  pill: 999,
};

export const typography = StyleSheet.create({
  title: {
    color: colors.text,
    fontSize: 24,
    fontWeight: '600',
    lineHeight: 36,
  },
  sectionTitle: {
    color: colors.text,
    fontSize: 20,
    fontWeight: '600',
    lineHeight: 30,
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
    shadowColor: colors.text,
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.06,
    shadowRadius: 2,
    elevation: 1,
  },
  level2: {
    shadowColor: colors.text,
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.08,
    shadowRadius: 8,
    elevation: 3,
  },
  level3: {
    shadowColor: colors.text,
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.1,
    shadowRadius: 16,
    elevation: 6,
  },
});
