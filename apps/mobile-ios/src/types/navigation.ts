import type { Spot as SharedSpot } from '@nexus/shared';

export type CongestionLevel = 'empty' | 'normal' | 'busy' | 'full';

export type MapSpot = SharedSpot & {
  congestion: CongestionLevel;
  distance?: number;
  isDestination?: boolean;
  isOrigin?: boolean;
  kind?: 'place' | 'support' | 'current';
  relatedEventId?: string;
  relatedEvents?: number;
  travelEstimate?: string;
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
  empty: '空きあり',
  normal: '通常',
  busy: 'やや混雑',
  full: '混雑',
};
