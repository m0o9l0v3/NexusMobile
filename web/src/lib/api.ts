import type { EventItem, LogEvent, NearbyItem, Spot } from "../types";

const mockSpots: Spot[] = [
  {
    code: "NXS01",
    name: "Blue Sky Gate",
    description: "受付・総合案内。搭乗前に必要な最新情報をここで受け取れます。",
    tags: ["案内", "Wi-Fi", "休憩"],
    image: "https://images.unsplash.com/photo-1502920514313-52581002a659?auto=format&w=800&q=60",
    links: [{ label: "安全な回線の案内", url: "#" }],
  },
  {
    code: "OC22",
    name: "Open Campus Lab",
    description: "学生プロジェクトの展示ゾーン。ミニワークショップを開催中。",
    tags: ["展示", "体験"],
    image: "https://images.unsplash.com/photo-1545239351-1141bd82e8a6?auto=format&w=800&q=60",
    links: [{ label: "アンケート", url: "#" }],
  },
];

const mockEvents: EventItem[] = [
  {
    id: "evt-1",
    title: "ウェルカムブリーフィング",
    location: "Blue Sky Gate",
    start: "10:00",
    end: "10:20",
    spotCode: "NXS01",
  },
  {
    id: "evt-2",
    title: "学生プロジェクトツアー",
    location: "Open Campus Lab",
    start: "11:00",
    end: "11:45",
    spotCode: "OC22",
  },
];

const mockNearby = (lat: number, lng: number): NearbyItem[] => {
  const drift = Math.abs(Math.sin(lat + lng));
  return [
    {
      id: "near-1",
      name: "Blue Sky Gate",
      distanceM: 38 + Math.round(drift * 12),
      accuracyM: 12,
      category: "spot",
      code: "NXS01",
    },
    {
      id: "near-2",
      name: "学生プロジェクトツアー",
      distanceM: 120 + Math.round(drift * 20),
      accuracyM: 18,
      category: "event",
      code: "OC22",
      time: "11:00",
    },
    {
      id: "near-3",
      name: "カフェテラス",
      distanceM: 240,
      accuracyM: 25,
      category: "spot",
    },
  ];
};

const apiBase = (import.meta.env.VITE_API_BASE_URL as string | undefined) ?? "http://localhost:8787";
const useMock = ((import.meta.env.VITE_USE_MOCK as string | undefined) ?? "true") === "true";

const fetchJson = async <T>(input: RequestInfo | URL, init?: RequestInit): Promise<T> => {
  const res = await fetch(input, init);
  if (!res.ok) {
    throw new Error(`API error: ${res.status}`);
  }
  return res.json() as Promise<T>;
};

export const getSpotByCode = async (code: string): Promise<Spot> => {
  if (useMock) {
    const spot = mockSpots.find((s) => s.code.toLowerCase() === code.toLowerCase());
    if (!spot) throw new Error("スポットが見つかりません");
    await new Promise((r) => setTimeout(r, 280));
    return spot;
  }
  return fetchJson<Spot>(`${apiBase}/api/spots/by-code/${encodeURIComponent(code)}`);
};

export const getTodayEvents = async (): Promise<EventItem[]> => {
  if (useMock) {
    await new Promise((r) => setTimeout(r, 220));
    return mockEvents;
  }
  return fetchJson<EventItem[]>(`${apiBase}/api/events/today`);
};

export const getNearby = async (lat: number, lng: number, radiusM = 400): Promise<NearbyItem[]> => {
  if (useMock) {
    await new Promise((r) => setTimeout(r, 260));
    return mockNearby(lat, lng).map((item) => ({
      ...item,
      distanceM: Math.max(10, item.distanceM + Math.round(Math.random() * 40 - 20)),
      accuracyM: Math.max(5, item.accuracyM + Math.round(Math.random() * 10 - 5)),
    }));
  }
  const params = new URLSearchParams({ lat: String(lat), lng: String(lng), radius_m: String(radiusM) });
  return fetchJson<NearbyItem[]>(`${apiBase}/api/nearby?${params.toString()}`);
};

export const postLog = async (sessionId: string, events: LogEvent[]): Promise<void> => {
  if (useMock) return;
  await fetchJson(`${apiBase}/api/logs`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ sessionId, events }),
  });
};
