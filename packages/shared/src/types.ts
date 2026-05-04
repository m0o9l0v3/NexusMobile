export type Spot = {
  id: string;
  name: string;
  description?: string;
  category: string;
  floor: string;
  x: number;
  y: number;
  tags?: string[];
};

export type FloorMap = {
  id: string;
  name: string;
  imageUrl?: string;
  svgPath?: string;
  width: number;
  height: number;
};

export type RoutePoint = {
  x: number;
  y: number;
};

export type Route = {
  id: string;
  fromSpotId: string;
  toSpotId: string;
  floor: string;
  points: RoutePoint[];
  estimatedMinutes?: number;
  distanceMeters?: number;
};

export type EstimatedIndoorPosition = {
  floor: string;
  x?: number;
  y?: number;
  confidence: number;
  source: 'manual' | 'barometer' | 'sensor-fusion' | 'admin';
  updatedAt: string;
};
