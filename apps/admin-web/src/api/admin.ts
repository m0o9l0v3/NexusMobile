import { apiClient, baseUrl } from './client';
import type { components } from './schema';

export type Spot = components['schemas']['SpotResponse'];
export type SpotRequest = components['schemas']['SpotRequest'];
export type Event = components['schemas']['EventResponse'];
export type EventRequest = components['schemas']['EventRequest'];
export type OcDay = components['schemas']['OcDayResponse'];
export type OcDayRequest = components['schemas']['OcDayRequest'];
export type VisitLog = components['schemas']['VisitLogResponse'];

export async function login(payload: components['schemas']['LoginRequest']) {
  const { data, error } = await apiClient.POST('/admin/auth/login', { body: payload });
  if (error) {
    throw new Error('ログインに失敗しました。');
  }
  return data;
}

export async function fetchSpots() {
  const { data, error } = await apiClient.GET('/admin/spots');
  if (error) {
    throw new Error('スポット一覧の取得に失敗しました。');
  }
  return data ?? [];
}

export async function fetchSpot(id: string) {
  const { data, error } = await apiClient.GET('/admin/spots/{id}', { params: { path: { id } } });
  if (error) {
    throw new Error('スポット情報の取得に失敗しました。');
  }
  return data;
}

export async function createSpot(payload: SpotRequest) {
  const { data, error } = await apiClient.POST('/admin/spots', { body: payload });
  if (error) {
    throw new Error('スポットの作成に失敗しました。');
  }
  return data;
}

export async function updateSpot(id: string, payload: SpotRequest) {
  const { data, error } = await apiClient.PUT('/admin/spots/{id}', { params: { path: { id } }, body: payload });
  if (error) {
    throw new Error('スポットの更新に失敗しました。');
  }
  return data;
}

export async function deleteSpot(id: string) {
  const { error } = await apiClient.DELETE('/admin/spots/{id}', { params: { path: { id } } });
  if (error) {
    throw new Error('スポットの削除に失敗しました。');
  }
}

export async function publishSpot(id: string, isPublished: boolean) {
  const { data, error } = await apiClient.PATCH('/admin/spots/{id}/publish', {
    params: { path: { id } },
    body: { isPublished },
  });
  if (error) {
    throw new Error('公開状態の更新に失敗しました。');
  }
  return data;
}

export async function fetchSpotQr(id: string) {
  const token = localStorage.getItem('adminToken');
  const response = await fetch(`${baseUrl}/admin/spots/${id}/qr`, {
    headers: token ? { Authorization: `Bearer ${token}` } : undefined,
  });
  if (!response.ok) {
    throw new Error('QRコードの取得に失敗しました。');
  }
  return response.blob();
}

export async function fetchEvents() {
  const { data, error } = await apiClient.GET('/admin/events');
  if (error) {
    throw new Error('イベント一覧の取得に失敗しました。');
  }
  return data ?? [];
}

export async function fetchEvent(id: string) {
  const { data, error } = await apiClient.GET('/admin/events/{id}', { params: { path: { id } } });
  if (error) {
    throw new Error('イベント情報の取得に失敗しました。');
  }
  return data;
}

export async function createEvent(payload: EventRequest) {
  const { data, error } = await apiClient.POST('/admin/events', { body: payload });
  if (error) {
    throw new Error('イベントの作成に失敗しました。');
  }
  return data;
}

export async function updateEvent(id: string, payload: EventRequest) {
  const { data, error } = await apiClient.PUT('/admin/events/{id}', { params: { path: { id } }, body: payload });
  if (error) {
    throw new Error('イベントの更新に失敗しました。');
  }
  return data;
}

export async function deleteEvent(id: string) {
  const { error } = await apiClient.DELETE('/admin/events/{id}', { params: { path: { id } } });
  if (error) {
    throw new Error('イベントの削除に失敗しました。');
  }
}

export async function publishEvent(id: string, isPublished: boolean) {
  const { data, error } = await apiClient.PATCH('/admin/events/{id}/publish', {
    params: { path: { id } },
    body: { isPublished },
  });
  if (error) {
    throw new Error('公開状態の更新に失敗しました。');
  }
  return data;
}

export async function fetchOcDays() {
  const { data, error } = await apiClient.GET('/admin/oc-days');
  if (error) {
    throw new Error('オープンキャンパス日程の取得に失敗しました。');
  }
  return data ?? [];
}

export async function createOcDay(payload: OcDayRequest) {
  const { data, error } = await apiClient.POST('/admin/oc-days', { body: payload });
  if (error) {
    throw new Error('オープンキャンパス日の登録に失敗しました。');
  }
  return data;
}

export async function deleteOcDay(id: string) {
  const { error } = await apiClient.DELETE('/admin/oc-days/{id}', { params: { path: { id } } });
  if (error) {
    throw new Error('オープンキャンパス日の削除に失敗しました。');
  }
}

export async function fetchRecentLogs(limit = 100) {
  const { data, error } = await apiClient.GET('/admin/logs/recent', { params: { query: { limit } } });
  if (error) {
    throw new Error('ログの取得に失敗しました。');
  }
  return data ?? [];
}
