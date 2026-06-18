import { useEffect, useState } from 'react';
import { getTodayEvents } from '../src/api/events';
import { HomeScreen } from '../src/components/HomeScreen';
import type { CampusEvent } from '../src/types/events';

const fallbackEvents: CampusEvent[] = [
  { id: '1', title: '工学部説明会', time: '11:00', location: '講義室A', department: '工学部', category: '説明会' },
  { id: '2', title: 'キャンパスツアー', time: '11:30', location: '受付集合', department: '全体', category: 'ツアー' },
  { id: '3', title: '模擬授業: AI入門', time: '13:00', location: '実験室B', department: '情報学部', category: '模擬授業' },
];

export default function HomeRoute() {
  const [events, setEvents] = useState<CampusEvent[]>(fallbackEvents);

  useEffect(() => {
    getTodayEvents()
      .then(setEvents)
      .catch(() => setEvents(fallbackEvents));
  }, []);

  return <HomeScreen events={events} />;
}
