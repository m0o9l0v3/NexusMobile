import Svg, { Circle, Line, Path, Rect } from 'react-native-svg';

type IconName =
  | 'arrowRight'
  | 'briefcase'
  | 'building'
  | 'calendar'
  | 'chevronRight'
  | 'check'
  | 'clock'
  | 'door'
  | 'filter'
  | 'helpCircle'
  | 'home'
  | 'info'
  | 'map'
  | 'mapPin'
  | 'navigation'
  | 'plane'
  | 'search'
  | 'shield'
  | 'swap'
  | 'users'
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
      {name === 'users' && (
        <>
          <Circle cx="9" cy="8" r="3" stroke={color} strokeWidth={strokeWidth} />
          <Path d="M3.5 19c.7-3.2 2.8-5 5.5-5s4.8 1.8 5.5 5" stroke={color} strokeWidth={strokeWidth} strokeLinecap="round" />
          <Path d="M15 11c1.7-.2 3-1.5 3-3.2 0-1.3-.8-2.5-2-3" stroke={color} strokeWidth={strokeWidth} strokeLinecap="round" />
          <Path d="M16.5 14c2.1.6 3.5 2.2 4 5" stroke={color} strokeWidth={strokeWidth} strokeLinecap="round" />
        </>
      )}
      {name === 'helpCircle' && (
        <>
          <Circle cx="12" cy="12" r="9" stroke={color} strokeWidth={strokeWidth} />
          <Path d="M9.8 9.3a2.5 2.5 0 1 1 3.7 2.2c-.9.5-1.5 1-1.5 2" stroke={color} strokeWidth={strokeWidth} strokeLinecap="round" />
          <Circle cx="12" cy="17" r="0.8" fill={color} />
        </>
      )}
      {name === 'info' && (
        <>
          <Circle cx="12" cy="12" r="9" stroke={color} strokeWidth={strokeWidth} />
          <Line x1="12" y1="11" x2="12" y2="17" stroke={color} strokeWidth={strokeWidth} strokeLinecap="round" />
          <Circle cx="12" cy="7.5" r="0.8" fill={color} />
        </>
      )}
      {name === 'check' && <Path d="m5 12 4 4 10-10" stroke={color} strokeWidth={strokeWidth} strokeLinecap="round" strokeLinejoin="round" />}
      {name === 'building' && (
        <>
          <Rect x="5" y="4" width="14" height="17" rx="2" stroke={color} strokeWidth={strokeWidth} />
          <Line x1="9" y1="8" x2="9" y2="8.5" stroke={color} strokeWidth={strokeWidth} strokeLinecap="round" />
          <Line x1="15" y1="8" x2="15" y2="8.5" stroke={color} strokeWidth={strokeWidth} strokeLinecap="round" />
          <Line x1="9" y1="12" x2="9" y2="12.5" stroke={color} strokeWidth={strokeWidth} strokeLinecap="round" />
          <Line x1="15" y1="12" x2="15" y2="12.5" stroke={color} strokeWidth={strokeWidth} strokeLinecap="round" />
          <Path d="M10 21v-4h4v4" stroke={color} strokeWidth={strokeWidth} strokeLinejoin="round" />
        </>
      )}
      {name === 'briefcase' && (
        <>
          <Rect x="4" y="8" width="16" height="11" rx="2" stroke={color} strokeWidth={strokeWidth} />
          <Path d="M9 8V6.5A1.5 1.5 0 0 1 10.5 5h3A1.5 1.5 0 0 1 15 6.5V8" stroke={color} strokeWidth={strokeWidth} />
          <Path d="M4 12h16" stroke={color} strokeWidth={strokeWidth} />
        </>
      )}
      {name === 'shield' && <Path d="M12 3 19 6v5c0 4.5-2.8 8-7 10-4.2-2-7-5.5-7-10V6l7-3Z" stroke={color} strokeWidth={strokeWidth} strokeLinejoin="round" />}
      {name === 'door' && (
        <>
          <Path d="M6 21V4h10v17" stroke={color} strokeWidth={strokeWidth} strokeLinejoin="round" />
          <Path d="M16 21h3" stroke={color} strokeWidth={strokeWidth} strokeLinecap="round" />
          <Circle cx="13" cy="12" r="0.8" fill={color} />
        </>
      )}
      {name === 'plane' && <Path d="M3 12h18L13 4l-2 6H6l3 2-3 2h5l2 6 8-8H3Z" stroke={color} strokeWidth={strokeWidth} strokeLinejoin="round" />}
    </Svg>
  );
}
