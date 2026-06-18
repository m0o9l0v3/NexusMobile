import { useLocalSearchParams } from 'expo-router';
import { useEffect, useState } from 'react';
import { getTodayEvents } from '../src/api/events';
import { EventsScreen } from '../src/components/EventsScreen';
import type { CampusEvent } from '../src/types/events';

const fallbackEvents: CampusEvent[] = [
  { id: '1', title: '受付開始', time: '09:00', endTime: '09:30', location: '受付', floor: '1F', department: '全体', category: 'イベント', description: 'パンフレットと参加証をお渡しします。' },
  { id: '2', title: '工学部説明会', time: '10:00', endTime: '11:00', location: '講義室A', floor: '1F', department: '工学部', category: '説明会', description: '学部の特徴とカリキュラムを紹介します。' },
  { id: '3', title: 'キャンパスツアー', time: '10:30', endTime: '11:30', location: '受付集合', floor: '1F', department: '全体', category: 'ツアー', description: '学生スタッフがキャンパス内を案内します。' },
  { id: '4', title: '情報学部説明会', time: '11:00', endTime: '12:00', location: '講義室B', floor: '2F', department: '情報学部', category: '説明会', description: 'AIやデータサイエンスの研究を紹介します。' },
  { id: '5', title: 'ランチタイム', time: '12:00', endTime: '13:00', location: 'カフェテリア', floor: '2F', department: '全体', category: 'イベント', description: '学食体験ができます。' },
  { id: '6', title: '模擬授業: AI入門', time: '13:00', endTime: '14:00', location: '実験室B', floor: '3F', department: '情報学部', category: '模擬授業', description: '実際の授業を体験できます。' },
  { id: '7', title: '個別相談会', time: '14:00', endTime: '16:00', location: '相談室', floor: '2F', department: '全体', category: '相談会', description: '入試や学生生活について個別に相談できます。' },
];

export default function EventsRoute() {
  const params = useLocalSearchParams<{ eventId?: string }>();
  const [events, setEvents] = useState<CampusEvent[]>(fallbackEvents);

  useEffect(() => {
    getTodayEvents()
      .then(setEvents)
      .catch(() => setEvents(fallbackEvents));
  }, []);

  return <EventsScreen events={events} initialEventId={params.eventId} />;
}
