import { Users, UserCheck, AlertTriangle, Calendar } from 'lucide-react';
import { KPICard } from '../components/KPICard';
import { ChartCard } from '../components/ChartCard';
import { LineChart, Line, BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Legend } from 'recharts';

// Mock data
const checkinData = [
  { time: '09:00', チェックイン数: 45 },
  { time: '10:00', チェックイン数: 120 },
  { time: '11:00', チェックイン数: 185 },
  { time: '12:00', チェックイン数: 240 },
  { time: '13:00', チェックイン数: 280 },
  { time: '14:00', チェックイン数: 220 },
  { time: '15:00', チェックイン数: 180 },
  { time: '16:00', チェックイン数: 120 },
];

const eventData = [
  { name: 'トータルモビリティ工学科', 来場者: 145 },
  { name: '整備科', 来場者: 98 },
  { name: 'CA/GS科', 来場者: 76 },
  { name: 'グランドハンドリング学科', 来場者: 62 },
  { name: 'キャンパスツアー', 来場者: 134 },
];

const topSpots = [
  { name: 'PC教室', occupancy: 92, trend: 'up', current: 184, capacity: 200 },
  { name: '食堂', occupancy: 88, trend: 'up', current: 264, capacity: 300 },
  { name: 'CTC', occupancy: 75, trend: 'down', current: 150, capacity: 200 },
  { name: '体育館', occupancy: 65, trend: 'up', current: 195, capacity: 300 },
  { name: '格納庫', occupancy: 58, trend: 'down', current: 290, capacity: 500 },
];

const recentLogs = [
  { time: '15:42', type: '入場', user: '一般来場者', gate: 'ゲートA', spot: 'PC教室', status: '正常' },
  { time: '15:41', type: '退場', user: '高校生', gate: 'ゲートB', spot: 'CTC', status: '正常' },
  { time: '15:40', type: '入場', user: '保護者', gate: 'ゲートA', spot: '食堂', status: '正常' },
  { time: '15:39', type: 'エラー', user: '-', gate: 'ゲートC', spot: '-', status: 'QR無効' },
  { time: '15:38', type: '入場', user: '高校生', gate: 'ゲートA', spot: '', status: '正常' },
];

const notifications = [
  { time: '15:30', type: '混雑アラート', message: 'PC教室が混雑しています（稼働率92%）' },
  { time: '14:15', type: 'QR発行', message: '新規QRコード200件を発行しました' },
  { time: '13:45', type: '設定変更', message: '混雑通知の閾値を85%に変更しました' },
];

export function Dashboard() {
  return (
    <div className="space-y-6">
      {/* KPI Row */}
      <div className="grid grid-cols-4 gap-6">
        <KPICard
          title="現在の入場者数"
          value="1,247"
          delta="+12.5% 前回比"
          deltaType="increase"
          icon={Users}
          subtitle="合計入場者数"
        />
        <KPICard
          title="本日のチェックイン数"
          value="1,490"
          delta="+8.3% 前日比"
          deltaType="increase"
          icon={UserCheck}
        />
        <KPICard
          title="混雑スポット数"
          value="3"
          delta="-1 スポット"
          deltaType="decrease"
          icon={AlertTriangle}
          subtitle="閾値: 85%以上"
        />
        <KPICard
          title="稼働中イベント数"
          value="12"
          icon={Calendar}
          subtitle="本日開催"
        />
      </div>

      {/* Main Panel Split */}
      <div className="grid grid-cols-12 gap-6">
        {/* Campus Map / Heatmap */}
        <div className="col-span-8">
          <ChartCard title="キャンパスマップ / ヒートマップ" subtitle="リアルタイムの混雑状況">
            <div className="relative aspect-[16/10] rounded-xl bg-gradient-to-br from-blue-50 to-blue-100/50 p-6">
              {/* Campus map visualization */}
              <div className="grid grid-cols-3 gap-4 h-full">
                {topSpots.map((spot, i) => (
                  <div
                    key={i}
                    className={`relative rounded-lg border-2 ${
                      spot.occupancy >= 85
                        ? 'border-red-400 bg-red-100/80'
                        : spot.occupancy >= 70
                        ? 'border-orange-400 bg-orange-100/80'
                        : 'border-blue-400 bg-blue-100/80'
                    } p-4 shadow-sm backdrop-blur-sm`}
                  >
                    <div className="text-xs font-medium mb-1">{spot.name}</div>
                    <div className="text-2xl font-bold">{spot.occupancy}%</div>
                    <div className="text-xs text-muted-foreground">
                      {spot.current}/{spot.capacity}人
                    </div>
                  </div>
                ))}
              </div>
              {/* Legend */}
              <div className="absolute bottom-4 right-4 rounded-lg bg-white/90 p-3 shadow-md backdrop-blur-sm">
                <div className="text-xs font-medium mb-2">混雑度</div>
                <div className="flex gap-3 text-xs">
                  <div className="flex items-center gap-1">
                    <div className="h-3 w-3 rounded bg-blue-400"></div>
                    <span>～69%</span>
                  </div>
                  <div className="flex items-center gap-1">
                    <div className="h-3 w-3 rounded bg-orange-400"></div>
                    <span>70-84%</span>
                  </div>
                  <div className="flex items-center gap-1">
                    <div className="h-3 w-3 rounded bg-red-400"></div>
                    <span>85%～</span>
                  </div>
                </div>
              </div>
            </div>
          </ChartCard>
        </div>

        {/* Congestion Ranking */}
        <div className="col-span-4">
          <ChartCard title="混雑ランキング Top Spots" subtitle="現在の混雑状況">
            <div className="space-y-4">
              {topSpots.map((spot, i) => (
                <div key={i} className="space-y-2">
                  <div className="flex items-center justify-between text-sm">
                    <div className="flex items-center gap-2">
                      <span className="flex h-6 w-6 items-center justify-center rounded-full bg-primary/10 text-xs font-semibold text-primary">
                        {i + 1}
                      </span>
                      <span className="font-medium">{spot.name}</span>
                    </div>
                    <div className="flex items-center gap-2">
                      <span className="font-semibold">{spot.occupancy}%</span>
                      <span className={`text-xs ${spot.trend === 'up' ? 'text-red-600' : 'text-green-600'}`}>
                        {spot.trend === 'up' ? '↑' : '↓'}
                      </span>
                    </div>
                  </div>
                  <div className="h-2 overflow-hidden rounded-full bg-muted">
                    <div
                      className={`h-full rounded-full ${
                        spot.occupancy >= 85
                          ? 'bg-red-500'
                          : spot.occupancy >= 70
                          ? 'bg-orange-500'
                          : 'bg-blue-500'
                      }`}
                      style={{ width: `${spot.occupancy}%` }}
                    ></div>
                  </div>
                  <div className="text-xs text-muted-foreground">
                    {spot.current} / {spot.capacity}人
                  </div>
                </div>
              ))}
            </div>
          </ChartCard>
        </div>
      </div>

      {/* Secondary Row - Charts */}
      <div className="grid grid-cols-2 gap-6">
        <ChartCard title="チェックイン推移" subtitle="本日の時間帯別チェックイン数">
          <ResponsiveContainer width="100%" height={280}>
            <LineChart data={checkinData}>
              <CartesianGrid strokeDasharray="3 3" stroke="#e5e7eb" />
              <XAxis dataKey="time" stroke="#64748b" style={{ fontSize: '12px' }} />
              <YAxis stroke="#64748b" style={{ fontSize: '12px' }} />
              <Tooltip
                contentStyle={{
                  backgroundColor: 'white',
                  border: '1px solid #e5e7eb',
                  borderRadius: '8px',
                  boxShadow: '0 2px 8px rgba(0,0,0,0.1)',
                }}
              />
              <Line type="monotone" dataKey="チェックイン数" stroke="#2563eb" strokeWidth={2} dot={{ fill: '#2563eb', r: 4 }} />
            </LineChart>
          </ResponsiveContainer>
        </ChartCard>

        <ChartCard title="イベント別来場者" subtitle="本日開催中のイベント">
          <ResponsiveContainer width="100%" height={280}>
            <BarChart data={eventData}>
              <CartesianGrid strokeDasharray="3 3" stroke="#e5e7eb" />
              <XAxis dataKey="name" stroke="#64748b" style={{ fontSize: '12px' }} angle={-15} textAnchor="end" height={80} />
              <YAxis stroke="#64748b" style={{ fontSize: '12px' }} />
              <Tooltip
                contentStyle={{
                  backgroundColor: 'white',
                  border: '1px solid #e5e7eb',
                  borderRadius: '8px',
                  boxShadow: '0 2px 8px rgba(0,0,0,0.1)',
                }}
              />
              <Bar dataKey="来場者" fill="#06b6d4" radius={[8, 8, 0, 0]} />
            </BarChart>
          </ResponsiveContainer>
        </ChartCard>
      </div>

      {/* Activity + Logs Preview */}
      <div className="grid grid-cols-12 gap-6">
        {/* Recent Logs */}
        <div className="col-span-8">
          <ChartCard
            title="最新ログ"
            subtitle="リアルタイムのアクティビティ"
            actions={
              <>
                <button className="rounded-lg border border-border bg-primary/5 px-3 py-1 text-xs text-primary">
                  入場
                </button>
                <button className="rounded-lg border border-border px-3 py-1 text-xs hover:bg-accent">
                  退場
                </button>
                <button className="rounded-lg border border-border px-3 py-1 text-xs hover:bg-accent">
                  エラー
                </button>
              </>
            }
          >
            <div className="overflow-hidden rounded-lg border border-border">
              <table className="w-full">
                <thead className="bg-muted/50 text-xs">
                  <tr>
                    <th className="px-4 py-2 text-left font-medium">時刻</th>
                    <th className="px-4 py-2 text-left font-medium">タイプ</th>
                    <th className="px-4 py-2 text-left font-medium">来場者区分</th>
                    <th className="px-4 py-2 text-left font-medium">ゲート</th>
                    <th className="px-4 py-2 text-left font-medium">スポット</th>
                    <th className="px-4 py-2 text-left font-medium">ステータス</th>
                  </tr>
                </thead>
                <tbody className="text-sm">
                  {recentLogs.map((log, i) => (
                    <tr key={i} className="border-t border-border hover:bg-muted/30">
                      <td className="px-4 py-3">{log.time}</td>
                      <td className="px-4 py-3">
                        <span
                          className={`inline-flex rounded-full px-2 py-0.5 text-xs font-medium ${
                            log.type === '入場'
                              ? 'bg-green-100 text-green-700'
                              : log.type === '退場'
                              ? 'bg-blue-100 text-blue-700'
                              : 'bg-red-100 text-red-700'
                          }`}
                        >
                          {log.type}
                        </span>
                      </td>
                      <td className="px-4 py-3 text-muted-foreground">{log.user}</td>
                      <td className="px-4 py-3 text-muted-foreground">{log.gate}</td>
                      <td className="px-4 py-3">{log.spot}</td>
                      <td className="px-4 py-3">
                        <span
                          className={`text-xs ${
                            log.status === '正常' ? 'text-green-600' : 'text-red-600'
                          }`}
                        >
                          {log.status}
                        </span>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </ChartCard>
        </div>

        {/* System Notifications */}
        <div className="col-span-4">
          <ChartCard title="システム通知" subtitle="最新の通知">
            <div className="space-y-3">
              {notifications.map((notif, i) => (
                <div key={i} className="rounded-lg border border-border bg-muted/30 p-3">
                  <div className="flex items-start justify-between mb-1">
                    <span className="text-xs font-medium text-primary">{notif.type}</span>
                    <span className="text-xs text-muted-foreground">{notif.time}</span>
                  </div>
                  <p className="text-sm">{notif.message}</p>
                </div>
              ))}
            </div>
          </ChartCard>
        </div>
      </div>
    </div>
  );
}
