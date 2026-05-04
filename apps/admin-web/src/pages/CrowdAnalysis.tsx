import { AlertTriangle, TrendingUp, Users } from 'lucide-react';
import { ChartCard } from '../components/ChartCard';
import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, PieChart, Pie, Cell } from 'recharts';

const stayTimeData = [
  { spot: 'PC Room', minutes: 45 },
  { spot: 'Cafeteria', minutes: 32 },
  { spot: 'CTC', minutes: 28 },
  { spot: 'Lecture Room', minutes: 38 },
  { spot: 'Gym', minutes: 52 },
];

const visitorComposition = [
  { name: 'High School', value: 32, fill: '#3b82f6' },
  { name: 'Parents', value: 24, fill: '#06b6d4' },
  { name: 'College', value: 18, fill: '#8b5cf6' },
  { name: 'Faculty', value: 15, fill: '#ec4899' },
  { name: 'Other', value: 11, fill: '#f59e0b' },
];

const alerts = [
  { type: 'Crowded', location: 'PC Room', message: 'Occupancy reached 92%', severity: 'high' },
  { type: 'Long Stay', location: 'Cafeteria', message: 'Average stay is above 30 minutes', severity: 'medium' },
  { type: 'Scan Errors', location: 'East Gate', message: 'QR scan failures are increasing', severity: 'high' },
];

export function CrowdAnalysis() {
  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-2xl font-semibold text-foreground">Crowd Analysis</h2>
        <p className="mt-1 text-sm text-muted-foreground">Review visitor distribution and stay patterns.</p>
      </div>

      <div className="grid grid-cols-1 gap-6 xl:grid-cols-12">
        <div className="xl:col-span-8">
          <ChartCard title="Average Stay Time" subtitle="Minutes by spot">
            <ResponsiveContainer width="100%" height={320}>
              <BarChart data={stayTimeData}>
                <CartesianGrid strokeDasharray="3 3" stroke="#e5e7eb" />
                <XAxis dataKey="spot" stroke="#64748b" style={{ fontSize: '12px' }} />
                <YAxis stroke="#64748b" style={{ fontSize: '12px' }} />
                <Tooltip />
                <Bar dataKey="minutes" fill="#2563eb" radius={[8, 8, 0, 0]} />
              </BarChart>
            </ResponsiveContainer>
          </ChartCard>
        </div>

        <div className="xl:col-span-4 space-y-6">
          <div className="rounded-2xl border border-border bg-card p-6 shadow-sm">
            <div className="mb-4 flex items-start justify-between">
              <div>
                <h3 className="font-semibold text-foreground">Focus Spot</h3>
                <p className="text-sm text-muted-foreground">PC Room</p>
              </div>
              <AlertTriangle className="h-5 w-5 text-red-600" />
            </div>
            <div className="space-y-4">
              <div className="flex items-center justify-between">
                <span className="text-sm text-muted-foreground">Current visitors</span>
                <span className="text-2xl font-bold">184</span>
              </div>
              <div className="h-2 overflow-hidden rounded-full bg-muted">
                <div className="h-full w-[92%] rounded-full bg-red-500" />
              </div>
              <div className="flex items-center gap-2 text-sm text-red-600">
                <TrendingUp className="h-4 w-4" />
                <span>+12 in the last 15 minutes</span>
              </div>
              <div className="flex items-center gap-2 text-sm text-muted-foreground">
                <Users className="h-4 w-4" />
                <span>Capacity 200</span>
              </div>
            </div>
          </div>

          <ChartCard title="Visitor Mix" subtitle="By segment">
            <ResponsiveContainer width="100%" height={220}>
              <PieChart>
                <Pie data={visitorComposition} dataKey="value" cx="50%" cy="50%" outerRadius={80}>
                  {visitorComposition.map((item) => (
                    <Cell key={item.name} fill={item.fill} />
                  ))}
                </Pie>
                <Tooltip />
              </PieChart>
            </ResponsiveContainer>
            <div className="mt-4 space-y-2 text-xs">
              {visitorComposition.map((item) => (
                <div key={item.name} className="flex items-center justify-between">
                  <div className="flex items-center gap-2">
                    <div className="h-3 w-3 rounded" style={{ backgroundColor: item.fill }} />
                    <span>{item.name}</span>
                  </div>
                  <span className="font-medium">{item.value}%</span>
                </div>
              ))}
            </div>
          </ChartCard>
        </div>
      </div>

      <ChartCard title="Alerts" subtitle="Crowding and scan health">
        <div className="space-y-3">
          {alerts.map((alert) => (
            <div
              key={`${alert.type}-${alert.location}`}
              className={`rounded-lg border p-3 ${alert.severity === 'high' ? 'border-red-200 bg-red-50' : 'border-orange-200 bg-orange-50'}`}
            >
              <div className="mb-1 flex items-center justify-between">
                <span className="text-xs font-medium text-primary">{alert.type}</span>
                <span className="text-xs text-muted-foreground">{alert.location}</span>
              </div>
              <p className="text-sm">{alert.message}</p>
            </div>
          ))}
        </div>
      </ChartCard>
    </div>
  );
}
