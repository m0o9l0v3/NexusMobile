import { apiRequest } from '@/api/client';

export type TodayEventResponse = {
  id: string;
  title: string;
  description?: string | null;
  startTime: string;
  endTime: string;
  location?: string | null;
  spotCode?: string | null;
  imageUrl?: string | null;
  tags?: string[];
};

export type SpotByCodeResponse = {
  id: string;
  code: string;
  name: string;
  description: string;
  imageUrl?: string | null;
  latitude?: number | null;
  longitude?: number | null;
  isPublished: boolean;
  tags?: string[];
  arModelUrl?: string | null;
};

export type NearbySpotResponse = {
  id: string;
  code: string;
  name: string;
  distanceMeters: number;
  latitude: number;
  longitude: number;
  tags?: string[];
};

export type CreateLogRequest = {
  sessionId: string;
  eventType: string;
  spotCode?: string | null;
  payload?: unknown;
  occurredAt?: string;
  locationLat?: number | null;
  locationLng?: number | null;
  locationAccuracy?: number | null;
};

export type CreateLogBatchRequest = {
  logs: CreateLogRequest[];
};

export type AcceptedResponse = {
  accepted: boolean;
};

export const getTodayEvents = async (): Promise<TodayEventResponse[]> => {
  return apiRequest<TodayEventResponse[]>('/api/events/today');
};

export const getSpotByCode = async (code: string): Promise<SpotByCodeResponse> => {
  const safeCode = encodeURIComponent(code);
  return apiRequest<SpotByCodeResponse>(`/api/spots/by-code/${safeCode}`);
};

export const getNearbySpots = async (
  lat: number,
  lng: number,
  radius = 500,
): Promise<NearbySpotResponse[]> => {
  const search = new URLSearchParams({
    lat: String(lat),
    lng: String(lng),
    radius: String(radius),
  });

  return apiRequest<NearbySpotResponse[]>(`/api/nearby?${search.toString()}`);
};

export const postLog = async (payload: CreateLogRequest): Promise<AcceptedResponse> => {
  return apiRequest<AcceptedResponse>('/api/logs', {
    method: 'POST',
    body: payload,
    expectedStatuses: [202],
  });
};

export const postLogBatch = async (payload: CreateLogBatchRequest): Promise<AcceptedResponse> => {
  return apiRequest<AcceptedResponse>('/api/logs/batch', {
    method: 'POST',
    body: payload,
    expectedStatuses: [202],
  });
};
