import type { CampusEvent, TodayEventResponse } from '../types/events';
import { enrichCampusEvent } from '../data/openCampus';

const normalizeBaseUrl = (rawBaseUrl: string | undefined): string => {
  if (!rawBaseUrl) {
    return 'http://localhost:5001';
  }

  return rawBaseUrl.replace(/\/+$/, '');
};

const baseUrl = normalizeBaseUrl(process.env.EXPO_PUBLIC_API_BASE_URL);

const formatTime = (raw: string | undefined, fallback: string): string => {
  if (!raw) {
    return fallback;
  }

  const date = new Date(raw);
  if (Number.isNaN(date.getTime())) {
    return fallback;
  }

  return date.toLocaleTimeString('ja-JP', {
    hour: '2-digit',
    minute: '2-digit',
    hour12: false,
  });
};

const mapTodayEvent = (event: TodayEventResponse): CampusEvent => ({
  id: event.id,
  title: event.title,
  time: formatTime(event.startTime, '--:--'),
  endTime: formatTime(event.endTime, '--:--'),
  location: event.location ?? '会場未設定',
  department: '全体',
  category: event.tags?.[0] ?? 'イベント',
  description: event.description ?? '',
});

export const getTodayEvents = async (): Promise<CampusEvent[]> => {
  const response = await fetch(`${baseUrl}/api/events/today`);
  if (!response.ok) {
    throw new Error(`Request failed: ${response.status}`);
  }

  const payload = (await response.json()) as TodayEventResponse[];
  return payload.map((event) => enrichCampusEvent(mapTodayEvent(event)));
};
