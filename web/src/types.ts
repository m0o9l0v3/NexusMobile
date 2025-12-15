export type Spot = {
  code: string;
  name: string;
  description: string;
  tags?: string[];
  image?: string;
  links?: { label: string; url: string }[];
};

export type EventItem = {
  id: string;
  title: string;
  location: string;
  start: string;
  end: string;
  spotCode?: string;
};

export type NearbyItem = {
  id: string;
  name: string;
  distanceM: number;
  accuracyM: number;
  category: "spot" | "event";
  code?: string;
  time?: string;
};

export type LogEvent = {
  type: "qr_scan" | "spot_view" | "nearby_impression" | "error";
  payload?: Record<string, unknown>;
};
