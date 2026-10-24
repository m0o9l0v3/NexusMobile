export type EstimatedIndoorPosition = {
  floor: string;
  x?: number;
  y?: number;
  confidence: number;
  source: 'manual' | 'barometer' | 'sensor-fusion' | 'admin';
  updatedAt: string;
};
