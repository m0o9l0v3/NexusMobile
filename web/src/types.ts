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

export type Department = "トータルモビリティ工学科" | "CA/GS科" | "整備科" | "グランドハンドリング科";

export type CheckinProfileData = {
  name: string;
  age: number;
  highSchool: string;
  department: Department;
};

export type CheckinProfile = {
  checkedIn: boolean;
  profile: CheckinProfileData;
  sessionId?: string;
  checkedAt: string;
};
