# Nexus Campus PWA - Design System Documentation

## Overview

A Material Design 3 compliant design system for a Japanese university open campus visitor PWA, featuring a calm "endless blue sky" aesthetic with minimal visual noise and mobile-first UX patterns.

---

## Design Principles

### 1. **Calm Atmosphere (静かな雰囲気)**
- Subtle pale sky-blue gradients for backgrounds
- Near-neutral tones for map screens to reduce visual noise
- Low color area usage - information density without overwhelming

### 2. **Minimal Floating UI (控えめな浮遊)**
- Large corner radius (16-24px)
- Subtle elevation shadows (Material 3 levels 1-3)
- Cards appear to "float" gently above surfaces

### 3. **Mobile-First & One-Handed Operation (片手操作)**
- 390x844px base viewport (iPhone 12/13 Pro)
- Primary actions within thumb reach (bottom third)
- 44px minimum tap targets
- Safe area insets for notched devices

### 4. **Accessibility & Performance**
- Optimized for low-end smartphones
- `prefers-reduced-motion` support
- High contrast text (WCAG AA)
- Tabular numerals for metrics

---

## Color System

### Primary Colors (Sky Tone)
```css
--sky-0: #F4FBFF        /* Lightest sky, backgrounds */
--sky-1: #DDF1FF        /* Light sky, gradient tops */
--sky-2: #A7D8FF        /* Primary weak, active states */
--primary: #0B5ED7      /* Primary blue, CTAs */
--primary-weak: #A7D8FF /* Primary tint for surfaces */
```

### Semantic Colors
```css
--text: #0B1B3A              /* Primary text, high emphasis */
--surface: #FFFFFF            /* Card backgrounds */
--outline: rgba(11, 27, 58, 0.12)  /* Borders, dividers */
--muted: #F4FBFF             /* Subtle backgrounds */
--muted-foreground: rgba(11, 27, 58, 0.6)  /* Secondary text */
```

### Congestion Status Colors
```css
--congestion-empty: #34A853   /* 空 - Empty/Available */
--congestion-normal: #FBBC04  /* 普 - Normal/Moderate */
--congestion-busy: #FF9800    /* 混 - Busy/Crowded */
--congestion-full: #EA4335    /* 満 - Full/Maximum */
```

### State Layers (Material 3)
```css
--state-hover: rgba(11, 94, 215, 0.08)
--state-pressed: rgba(11, 94, 215, 0.12)
```

---

## Elevation (Material 3)

### Level 1 - Subtle
```css
box-shadow: 0 1px 2px rgba(11, 27, 58, 0.06);
```
**Usage:** Resting cards, list items

### Level 2 - Floating
```css
box-shadow: 0 2px 8px rgba(11, 27, 58, 0.08), 
            0 1px 3px rgba(11, 27, 58, 0.06);
```
**Usage:** Floating action buttons, search bars, navigation

### Level 3 - Modal
```css
box-shadow: 0 4px 16px rgba(11, 27, 58, 0.10), 
            0 2px 6px rgba(11, 27, 58, 0.08);
```
**Usage:** Bottom sheets, dialogs, modals

---

## Typography

### Fonts
- **Primary:** Noto Sans JP (400, 500, 700)
- **Secondary:** Inter (400, 500, 600, 700)
- **Fallback:** -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif

### Scale
```css
h1: 24px / 1.5 / 500  /* Page titles */
h2: 20px / 1.5 / 500  /* Section headers */
h3: 18px / 1.5 / 500  /* Card titles */
h4: 16px / 1.5 / 500  /* Subsections */
body: 16px / 1.5 / 400  /* Body text */
label: 16px / 1.5 / 500  /* Form labels */
caption: 14px / 1.5 / 400  /* Helper text */
small: 12px / 1.5 / 400  /* Metadata */
xs: 10-11px / 1.5 / 500  /* Badges, chips */
```

### Special Features
- **Tabular Numerals:** For distances, times, counts
  ```css
  font-variant-numeric: tabular-nums;
  ```

---

## Spacing Grid

8dp base unit (8px = 0.5rem)

```
4px  = 0.25rem = xs
8px  = 0.5rem  = sm
12px = 0.75rem = md
16px = 1rem    = lg
24px = 1.5rem  = xl
32px = 2rem    = 2xl
48px = 3rem    = 3xl
```

---

## Border Radius

```css
--radius-sm: 8px   /* Small elements (badges) */
--radius-md: 12px  /* Buttons, inputs */
--radius-lg: 16px  /* Cards, containers */
--radius-xl: 24px  /* Bottom sheets, modals */
--radius-full: 9999px  /* Circular buttons, pills */
```

---

## Component Library

### 1. Bottom Navigation (3 tabs only)
- **Tabs:** Home, Map, Events
- **Height:** 56px + safe-area-inset-bottom
- **Active state:** Pill background with primary-weak color
- **Animation:** Shared element transition (layoutId)

### 2. Bottom Sheet (5 variants)
#### Idle
- **Height:** 120px
- **Content:** Handle + hint text
- **Interaction:** Swipe up to reveal search

#### Search
- **Height:** 50vh
- **Content:** Category chips + search results list
- **Features:** Real-time filtering, distance display

#### Spot Detail
- **Height:** auto (content-dependent)
- **Content:** Title, tags, congestion badge, 3 action buttons
- **Actions:** Navigate, View events, Favorite

#### Route
- **Height:** 60vh
- **Content:** ETA summary, next step highlight, step-by-step list
- **Features:** Numbered steps, distance per segment

#### Filters
- **Height:** 50vh
- **Content:** Category chips, congestion filters, accessibility toggles
- **Actions:** Apply filters button

### 3. Congestion Badge
```tsx
<CongestionBadge level="empty" />  // 空
<CongestionBadge level="normal" /> // 普
<CongestionBadge level="busy" />   // 混
<CongestionBadge level="full" />   // 満
```
- **Variants:** default (24px height), small (20px height)
- **Style:** Outlined with fill background, colored border
- **Design:** Low color area usage (background at 10% opacity)

### 4. Map Marker
- **Size:** 40x40px touchable area
- **Visual:** 
  - Outer ring (congestion indicator, animated pulse when selected)
  - Inner dot (8px, white with primary border or solid for origin/destination)
- **Hover:** Tooltip with spot name
- **Animation:** Scale on tap, pulse on selection

### 5. Floor Switcher
- **Type:** Segmented control
- **Options:** Outdoor, B1, 1F, 2F, 3F
- **Style:** Pill background for active floor
- **Animation:** Smooth background transition (layoutId)

### 6. Event Card
- **Layout:** Horizontal with time badge + content
- **Time badge:** 48px width, primary-weak background
- **Content:** Title, location, department, description
- **Action:** Tap to open bottom sheet

### 7. Floating Search Bar
- **Position:** Top of map screen
- **Style:** Surface background, elev-2 shadow
- **Size:** Flexible width, 48px height
- **Icon:** Search icon (18px) on left

---

## Screen Specifications

### Home Screen
- **Hero section:** Gradient background (sky-1 → sky-0)
- **Primary CTA:** "Open Map" button (56px height, full width)
- **Next Events:** List of 3 upcoming events
- **Recommended Spots:** 2-column grid with cards

### Map Screen
- **Layout:** Full-screen map with overlays
- **Top bar:** Search + Floor switcher
- **Right side:** Zoom controls + Filter button
- **Bottom:** Bottom sheet (5 states)
- **Background:** Near-neutral to reduce noise on map

### Events Screen
- **Header:** Fixed with filter chips (scrollable horizontal)
- **Content:** Timeline grouped by hour
- **Time markers:** Pill badges at start of each hour group
- **Event cards:** Full width with left accent line

---

## Interaction Patterns

### Tap Targets
- **Minimum:** 44x44px (Apple HIG, WCAG)
- **Recommended:** 48x48px for primary actions
- **Spacing:** 8px minimum between targets

### Animations
- **Duration:** 200-300ms for state changes
- **Easing:** Spring physics (stiffness: 300, damping: 30)
- **Reduced motion:** Instant transitions when `prefers-reduced-motion: reduce`

### Gestures
- **Bottom sheet:** Drag handle, swipe to dismiss
- **Map:** Pinch to zoom (simulated with +/- buttons)
- **Lists:** Vertical scroll with momentum

---

## Accessibility

### Keyboard Navigation
- Tab order follows visual hierarchy
- Focus indicators visible (2px ring, primary color)

### Screen Readers
- Semantic HTML (nav, main, section, article)
- ARIA labels for icon-only buttons
- Live regions for dynamic content updates

### Color Contrast
- Text on surface: 14.2:1 (AAA)
- Primary on white: 6.8:1 (AA)
- Congestion badges: Border ensures visibility

---

## Performance Guidelines

### Images
- Use placeholder SVGs for map
- Lazy load event images
- Optimize icons (lucide-react, tree-shakeable)

### Animations
- Use `transform` and `opacity` only (GPU-accelerated)
- Avoid layout thrashing
- Debounce scroll/resize handlers

### Bundle Size
- Code splitting per screen
- Tree-shake unused components
- Compress assets

---

## Usage Examples

### Creating a New Screen
```tsx
import { motion } from 'motion/react';

export function NewScreen() {
  return (
    <div className="h-full overflow-y-auto pb-24">
      {/* Content */}
    </div>
  );
}
```

### Using Elevation
```tsx
<div 
  className="rounded-2xl p-4"
  style={{
    backgroundColor: 'var(--surface)',
    boxShadow: 'var(--elev-2)',
  }}
>
  {/* Card content */}
</div>
```

### Animated State Transition
```tsx
<motion.button
  whileTap={{ scale: 0.98 }}
  style={{
    backgroundColor: 'var(--primary)',
    color: 'var(--primary-foreground)',
  }}
>
  Action
</motion.button>
```

---

## Design Deliverables Checklist

- [x] Color palette with CSS variables
- [x] Typography scale with Japanese font support
- [x] Elevation system (3 levels)
- [x] Spacing grid (8dp base)
- [x] Component library (11 core components)
- [x] 3 main screens (Home, Map, Events)
- [x] Bottom sheet with 5 state variants
- [x] Congestion visualization system
- [x] Animation & interaction specifications
- [x] Accessibility guidelines
- [x] Mobile-first responsive patterns

---

## Maintenance & Evolution

### Adding New Colors
1. Define in `:root` with `--` prefix
2. Add to `@theme inline` for Tailwind
3. Document usage and contrast ratios

### Creating New Components
1. Follow Material 3 patterns
2. Use existing color/spacing tokens
3. Add to component library section
4. Test on 390px viewport

### Updating Typography
1. Maintain scale ratios
2. Test Japanese text rendering
3. Verify line heights for CJK characters

---

**Version:** 1.0  
**Last Updated:** 2026-01-29  
**Maintained by:** Nexus Development Team
