import type { FloorMap, Route, Spot } from './types';

export type NavigationApiClientOptions = {
  baseUrl: string;
  fetchImpl?: typeof fetch;
};

export function createNavigationApiClient({ baseUrl, fetchImpl = fetch }: NavigationApiClientOptions) {
  const request = async <T>(path: string): Promise<T> => {
    const res = await fetchImpl(`${baseUrl}${path}`);
    if (!res.ok) throw new Error(`Request failed: ${res.status}`);
    return (await res.json()) as T;
  };

  return {
    getSpots: () => request<Spot[]>('/api/spots'),
    getFloors: () => request<FloorMap[]>('/api/floors'),
    getRoutes: (from: string, to: string) => request<Route[]>(`/api/routes?from=${encodeURIComponent(from)}&to=${encodeURIComponent(to)}`)
  };
}
