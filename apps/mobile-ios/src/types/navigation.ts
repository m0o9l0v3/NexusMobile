import type { Spot as SharedSpot } from '@nexus/shared';

export type CongestionLevel = 'empty' | 'normal' | 'busy' | 'full';

export type MapSpot = SharedSpot & {
  congestion: CongestionLevel;
  distance?: number;
  isDestination?: boolean;
  isOrigin?: boolean;
  relatedEvents?: number;
};

export type RouteStep = {
  floor: string;
  landmark: string;
  distance?: number;
};

export type RouteInfo = {
  distance: number;
  duration: number;
  nextFloor?: string;
  nextLandmark?: string;
  steps: RouteStep[];
};

export const congestionLabels: Record<CongestionLevel, string> = {
  empty: '空き',
  normal: '普通',
  busy: '混雑',
  full: '満席',
};
