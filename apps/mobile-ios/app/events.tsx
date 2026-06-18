import { useLocalSearchParams } from 'expo-router';
import { useEffect, useState } from 'react';
import { getTodayEvents } from '../src/api/events';
import { EventsScreen } from '../src/components/EventsScreen';
import { openCampusEvents } from '../src/data/openCampus';
import type { CampusEvent } from '../src/types/events';

export default function EventsRoute() {
  const params = useLocalSearchParams<{ eventId?: string }>();
  const [events, setEvents] = useState<CampusEvent[]>(openCampusEvents);

  useEffect(() => {
    getTodayEvents()
      .then(setEvents)
      .catch(() => setEvents(openCampusEvents));
  }, []);

  return <EventsScreen events={events} initialEventId={params.eventId} />;
}
