import { useEffect, useState } from 'react';
import { getTodayEvents } from '../src/api/events';
import { HomeScreen } from '../src/components/HomeScreen';
import { openCampusEvents } from '../src/data/openCampus';
import type { CampusEvent } from '../src/types/events';

export default function HomeRoute() {
  const [events, setEvents] = useState<CampusEvent[]>(openCampusEvents);

  useEffect(() => {
    getTodayEvents()
      .then(setEvents)
      .catch(() => setEvents(openCampusEvents));
  }, []);

  return <HomeScreen events={events} />;
}
