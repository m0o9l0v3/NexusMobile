import { Calendar, Users, UserCheck, AlertTriangle } from 'lucide-react';
import { KPICard } from '../components/KPICard';
import { ChartCard } from '../components/ChartCard';
import { LineChart, Line, BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from 'recharts';

const checkinData = [
  { time: '09:00', count: 45 },
  { time: '10:00', count: 120 },
  { time: '11:00', count: 185 },
  { time: '12:00', count: 240 },
  { time: '13:00', count: 280 },
  { time: '14:00', count: 220 },
  { time: '15:00', count: 180 },
  { time: '16:00', count: 120 },
];

const eventData = [
  { name: 'Trial Class', visitors: 145 },
  { name: 'Consultation', visitors: 98 },
  { name: 'Lab Tour', visitors: 76 },
  { name: 'Campus Tour', visitors: 62 },
  { name: 'Department Expo', visitors: 134 },
];

const topSpots = [
  { name: 'PC Room', occupancy: 92, current: 184, capacity: 200 },
  { name: 'Cafeteria', occupancy: 88, current: 264, capacity: 300 },
  { name: 'CTC', occupancy: 75, current: 150, capacity: 200 },
  { name: 'Lecture Room', occupancy: 65, current: 195, capacity: 300 },
  { name: 'Gym', occupancy: 58, current: 290, capacity: 500 },
];

export function Dashboard() {
  return (
    <div className="space-y-6">
      <div className="grid grid-cols-1 gap-6 md:grid-cols-2 xl:grid-cols-4">
        <KPICard
          title="Active Visitors"
          value="1,247"
          delta="+12.5% vs last run"
          deltaType="increase"
          icon={Users}
          subtitle="Across campus"
        />
        <KPICard
          title="Today's Check-ins"
          value="1,490"
          delta="+8.3% day over day"
          deltaType="increase"
          icon={UserCheck}
        />
        <KPICard
          title="Crowded Spots"
          value="3"
          delta="-1 spot"
          deltaType="decrease"
          icon={AlertTriangle}
          subtitle="Threshold over 85%"
        />
        <KPICard title="Live Events" value="12" icon={Calendar} subtitle="Today" />
      </div>

      <div className="grid grid-cols-1 gap-6 xl:grid-cols-12">
        <div className="xl:col-span-8">
          <ChartCard title="Check-in Trend" subtitle="By hour">
            <ResponsiveContainer width="100%" height={320}>
              <LineChart data={checkinData}>
                <CartesianGrid strokeDasharray="3 3" stroke="#e5e7eb" />
                <XAxis dataKey="time" stroke="#64748b" style={{ fontSize: '12px' }} />
                <YAxis stroke="#64748b" style={{ fontSize: '12px' }} />
                <Tooltip />
                <Line type="monotone" dataKey="count" stroke="#2563eb" strokeWidth={2} dot={{ r: 4 }} />
              </LineChart>
            </ResponsiveContainer>
          </ChartCard>
        </div>

        <div className="xl:col-span-4">
          <ChartCard title="Top Spots" subtitle="Current occupancy">
            <div className="space-y-4">
              {topSpots.map((spot, index) => (
                <div key={spot.name} className="space-y-2">
                  <div className="flex items-center justify-between text-sm">
                    <span className="font-medium">
                      {index + 1}. {spot.name}
                    </span>
                    <span className="font-semibold">{spot.occupancy}%</span>
                  </div>
                  <div className="h-2 overflow-hidden rounded-full bg-muted">
                    <div className="h-full rounded-full bg-primary" style={{ width: `${spot.occupancy}%` }} />
                  </div>
                  <div className="text-xs text-muted-foreground">
                    {spot.current} / {spot.capacity} people
                  </div>
                </div>
              ))}
            </div>
          </ChartCard>
        </div>
      </div>

      <ChartCard title="Visitors by Event" subtitle="Today">
        <ResponsiveContainer width="100%" height={280}>
          <BarChart data={eventData}>
            <CartesianGrid strokeDasharray="3 3" stroke="#e5e7eb" />
            <XAxis dataKey="name" stroke="#64748b" style={{ fontSize: '12px' }} />
            <YAxis stroke="#64748b" style={{ fontSize: '12px' }} />
            <Tooltip />
            <Bar dataKey="visitors" fill="#06b6d4" radius={[8, 8, 0, 0]} />
          </BarChart>
        </ResponsiveContainer>
      </ChartCard>
    </div>
  );
}
