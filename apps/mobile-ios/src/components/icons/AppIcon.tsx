import Svg, { Circle, Line, Path, Rect } from 'react-native-svg';

type IconName =
  | 'arrowRight'
  | 'calendar'
  | 'chevronRight'
  | 'clock'
  | 'filter'
  | 'home'
  | 'map'
  | 'mapPin'
  | 'navigation'
  | 'search'
  | 'swap'
  | 'x';

type AppIconProps = {
  name: IconName;
  size?: number;
  color?: string;
  strokeWidth?: number;
};

export function AppIcon({ name, size = 20, color = 'currentColor', strokeWidth = 2 }: AppIconProps) {
  return (
    <Svg width={size} height={size} viewBox="0 0 24 24" fill="none">
      {name === 'home' && (
        <>
          <Path d="M3 11L12 4l9 7" stroke={color} strokeWidth={strokeWidth} strokeLinecap="round" strokeLinejoin="round" />
          <Path d="M5 10v9h5v-5h4v5h5v-9" stroke={color} strokeWidth={strokeWidth} strokeLinecap="round" strokeLinejoin="round" />
        </>
      )}
      {name === 'calendar' && (
        <>
          <Rect x="4" y="5" width="16" height="15" rx="2" stroke={color} strokeWidth={strokeWidth} />
          <Line x1="8" y1="3" x2="8" y2="7" stroke={color} strokeWidth={strokeWidth} strokeLinecap="round" />
          <Line x1="16" y1="3" x2="16" y2="7" stroke={color} strokeWidth={strokeWidth} strokeLinecap="round" />
          <Line x1="4" y1="10" x2="20" y2="10" stroke={color} strokeWidth={strokeWidth} />
        </>
      )}
      {name === 'mapPin' && (
        <>
          <Path d="M12 21s7-5.2 7-11a7 7 0 0 0-14 0c0 5.8 7 11 7 11Z" stroke={color} strokeWidth={strokeWidth} strokeLinejoin="round" />
          <Circle cx="12" cy="10" r="2.3" stroke={color} strokeWidth={strokeWidth} />
        </>
      )}
      {name === 'map' && (
        <>
          <Path d="M8 5 3 7v14l5-2 8 2 5-2V5l-5 2-8-2Z" stroke={color} strokeWidth={strokeWidth} strokeLinejoin="round" />
          <Line x1="8" y1="5" x2="8" y2="19" stroke={color} strokeWidth={strokeWidth} />
          <Line x1="16" y1="7" x2="16" y2="21" stroke={color} strokeWidth={strokeWidth} />
        </>
      )}
      {name === 'search' && (
        <>
          <Circle cx="10.5" cy="10.5" r="6.5" stroke={color} strokeWidth={strokeWidth} />
          <Line x1="15.5" y1="15.5" x2="21" y2="21" stroke={color} strokeWidth={strokeWidth} strokeLinecap="round" />
        </>
      )}
      {name === 'filter' && <Path d="M4 6h16l-6 7v5l-4 2v-7L4 6Z" stroke={color} strokeWidth={strokeWidth} strokeLinejoin="round" />}
      {name === 'clock' && (
        <>
          <Circle cx="12" cy="12" r="8" stroke={color} strokeWidth={strokeWidth} />
          <Path d="M12 8v5l3 2" stroke={color} strokeWidth={strokeWidth} strokeLinecap="round" strokeLinejoin="round" />
        </>
      )}
      {name === 'arrowRight' && (
        <>
          <Line x1="5" y1="12" x2="19" y2="12" stroke={color} strokeWidth={strokeWidth} strokeLinecap="round" />
          <Path d="m13 6 6 6-6 6" stroke={color} strokeWidth={strokeWidth} strokeLinecap="round" strokeLinejoin="round" />
        </>
      )}
      {name === 'chevronRight' && <Path d="m9 6 6 6-6 6" stroke={color} strokeWidth={strokeWidth} strokeLinecap="round" strokeLinejoin="round" />}
      {name === 'x' && (
        <>
          <Line x1="6" y1="6" x2="18" y2="18" stroke={color} strokeWidth={strokeWidth} strokeLinecap="round" />
          <Line x1="18" y1="6" x2="6" y2="18" stroke={color} strokeWidth={strokeWidth} strokeLinecap="round" />
        </>
      )}
      {name === 'navigation' && <Path d="m4 13 16-9-7 16-2-7-7-0Z" stroke={color} strokeWidth={strokeWidth} strokeLinejoin="round" />}
      {name === 'swap' && (
        <>
          <Path d="M7 7h11l-3-3" stroke={color} strokeWidth={strokeWidth} strokeLinecap="round" strokeLinejoin="round" />
          <Path d="M17 17H6l3 3" stroke={color} strokeWidth={strokeWidth} strokeLinecap="round" strokeLinejoin="round" />
        </>
      )}
    </Svg>
  );
}
