import { AlertTriangle, Users, TrendingUp } from 'lucide-react';
import { ChartCard } from '../components/ChartCard';
import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Cell, PieChart, Pie } from 'recharts';

const stayTimeData = [
  { spot: 'PC教室', 平均滞在時間: 45 },
  { spot: '食堂', 平均滞在時間: 32 },
  { spot: 'CTC', 平均滞在時間: 28 },
  { spot: '体育館', 平均滞在時間: 38 },
  { spot: '', 平均滞在時間: 52 },
  { spot: 'カフェテリア', 平均滞在時間: 25 },
];

const visitorComposition = [
  { name: '工学部', value: 32, fill: '#3b82f6' },
  { name: '経済学部', value: 24, fill: '#06b6d4' },
  { name: '医学部', value: 18, fill: '#8b5cf6' },
  { name: '文学部', value: 15, fill: '#ec4899' },
  { name: 'その他', value: 11, fill: '#f59e0b' },
];

const visitorTypeData = [
  { name: '高校生', value: 45, fill: '#2563eb' },
  { name: '保護者', value: 30, fill: '#06b6d4' },
  { name: '一般', value: 25, fill: '#8b5cf6' },
];

const alerts = [
  { type: '混雑', location: 'PC教室', message: '混雑率92% - 入場制限を推奨', severity: 'high' },
  { type: '滞留', location: '食堂', message: '平均滞在時間が20分増加', severity: 'medium' },
  { type: '異常', location: 'ゲートC', message: 'QRスキャナーエラー率上昇中', severity: 'high' },
];

export function CrowdAnalysis() {
  return (
    <div className="space-y-6">
      {/* Page Header */}
      <div>
        <h2 className="text-2xl font-semibold text-foreground">混雑分析</h2>
        <p className="text-sm text-muted-foreground mt-1">
          来場者の位置情報とスポット集中度を分析
        </p>
      </div>

      {/* Top Controls */}
      <div className="flex items-center gap-4">
        <div className="flex items-center gap-2">
          <span className="text-sm font-medium">日時範囲:</span>
          <input
            type="datetime-local"
            className="rounded-lg border border-border bg-card px-3 py-1.5 text-sm focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary/20"
            defaultValue="2026-01-28T09:00"
          />
          <span className="text-sm text-muted-foreground">～</span>
          <input
            type="datetime-local"
            className="rounded-lg border border-border bg-card px-3 py-1.5 text-sm focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary/20"
            defaultValue="2026-01-28T17:00"
          />
        </div>
        
        <div className="flex items-center gap-2">
          <span className="text-sm font-medium">セグメント:</span>
          <button className="rounded-lg border border-primary bg-primary/10 px-3 py-1.5 text-sm text-primary">
            全体
          </button>
          <button className="rounded-lg border border-border px-3 py-1.5 text-sm hover:bg-accent">
            学科別
          </button>
          <button className="rounded-lg border border-border px-3 py-1.5 text-sm hover:bg-accent">
            招待区分
          </button>
        </div>

        <div className="flex items-center gap-2">
          <span className="text-sm font-medium">階層:</span>
          <select className="rounded-lg border border-border bg-card px-3 py-1.5 text-sm focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary/20">
            <option>全フロア</option>
            <option>1F</option>
            <option>2F</option>
            <option>3F</option>
            <option>4F</option>
          </select>
        </div>
      </div>

      {/* Main Content */}
      <div className="grid grid-cols-12 gap-6">
        {/* Large Interactive Map */}
        <div className="col-span-8">
          <ChartCard title="キャンパスマップ - ヒートマップビュー" subtitle="リアルタイムの来場者分布">
            <div className="relative aspect-[4/3] rounded-xl bg-gradient-to-br from-blue-50 to-slate-100 p-6">
              {/* Heatmap overlay simulation */}
              <div className="absolute inset-6 grid grid-cols-4 gap-3">
                {/* Building representations with density */}
                <div className="relative col-span-2 rounded-lg bg-red-200/60 p-4 shadow-inner backdrop-blur-sm border-2 border-red-400">
                  <div className="absolute top-2 left-2 rounded bg-white/90 px-2 py-1 text-xs font-medium shadow">
                    工学部棟A
                  </div>
                  <div className="absolute bottom-2 right-2 text-right">
                    <div className="text-2xl font-bold text-red-700">184人</div>
                    <div className="text-xs text-red-600">稼働率92%</div>
                  </div>
                  {/* Density dots */}
                  <div className="grid grid-cols-8 gap-1 mt-8">
                    {Array.from({ length: 48 }).map((_, i) => (
                      <div key={i} className="h-2 w-2 rounded-full bg-red-500/40"></div>
                    ))}
                  </div>
                </div>

                <div className="relative col-span-2 rounded-lg bg-orange-200/60 p-4 shadow-inner backdrop-blur-sm border-2 border-orange-400">
                  <div className="absolute top-2 left-2 rounded bg-white/90 px-2 py-1 text-xs font-medium shadow">
                    学生食堂
                  </div>
                  <div className="absolute bottom-2 right-2 text-right">
                    <div className="text-2xl font-bold text-orange-700">264人</div>
                    <div className="text-xs text-orange-600">稼働率88%</div>
                  </div>
                  <div className="grid grid-cols-8 gap-1 mt-8">
                    {Array.from({ length: 40 }).map((_, i) => (
                      <div key={i} className="h-2 w-2 rounded-full bg-orange-500/40"></div>
                    ))}
                  </div>
                </div>

                <div className="relative rounded-lg bg-blue-200/60 p-4 shadow-inner backdrop-blur-sm border-2 border-blue-400">
                  <div className="absolute top-2 left-2 rounded bg-white/90 px-2 py-1 text-xs font-medium shadow">
                    図書館
                  </div>
                  <div className="absolute bottom-2 right-2 text-right">
                    <div className="text-lg font-bold text-blue-700">150人</div>
                    <div className="text-xs text-blue-600">75%</div>
                  </div>
                  <div className="grid grid-cols-6 gap-1 mt-8">
                    {Array.from({ length: 24 }).map((_, i) => (
                      <div key={i} className="h-1.5 w-1.5 rounded-full bg-blue-500/40"></div>
                    ))}
                  </div>
                </div>

                <div className="relative rounded-lg bg-blue-200/60 p-4 shadow-inner backdrop-blur-sm border-2 border-blue-400">
                  <div className="absolute top-2 left-2 rounded bg-white/90 px-2 py-1 text-xs font-medium shadow">
                    体育館
                  </div>
                  <div className="absolute bottom-2 right-2 text-right">
                    <div className="text-lg font-bold text-blue-700">195人</div>
                    <div className="text-xs text-blue-600">65%</div>
                  </div>
                  <div className="grid grid-cols-6 gap-1 mt-8">
                    {Array.from({ length: 24 }).map((_, i) => (
                      <div key={i} className="h-1.5 w-1.5 rounded-full bg-blue-500/40"></div>
                    ))}
                  </div>
                </div>

                <div className="relative col-span-2 rounded-lg bg-green-200/60 p-4 shadow-inner backdrop-blur-sm border-2 border-green-400">
                  <div className="absolute top-2 left-2 rounded bg-white/90 px-2 py-1 text-xs font-medium shadow">
                    講堂
                  </div>
                  <div className="absolute bottom-2 right-2 text-right">
                    <div className="text-2xl font-bold text-green-700">290人</div>
                    <div className="text-xs text-green-600">稼働率58%</div>
                  </div>
                  <div className="grid grid-cols-8 gap-1 mt-8">
                    {Array.from({ length: 32 }).map((_, i) => (
                      <div key={i} className="h-2 w-2 rounded-full bg-green-500/40"></div>
                    ))}
                  </div>
                </div>
              </div>

              {/* Pin markers */}
              <div className="absolute top-12 left-12">
                <div className="h-4 w-4 animate-pulse rounded-full bg-red-500 shadow-lg"></div>
              </div>
              <div className="absolute top-20 right-20">
                <div className="h-4 w-4 animate-pulse rounded-full bg-orange-500 shadow-lg"></div>
              </div>

              {/* Legend */}
              <div className="absolute bottom-4 right-4 rounded-lg bg-white/95 p-3 shadow-lg backdrop-blur-sm">
                <div className="text-xs font-medium mb-2">密度レベル</div>
                <div className="space-y-1 text-xs">
                  <div className="flex items-center gap-2">
                    <div className="h-3 w-3 rounded bg-green-400"></div>
                    <span>低 (～60%)</span>
                  </div>
                  <div className="flex items-center gap-2">
                    <div className="h-3 w-3 rounded bg-blue-400"></div>
                    <span>中 (60-75%)</span>
                  </div>
                  <div className="flex items-center gap-2">
                    <div className="h-3 w-3 rounded bg-orange-400"></div>
                    <span>高 (75-85%)</span>
                  </div>
                  <div className="flex items-center gap-2">
                    <div className="h-3 w-3 rounded bg-red-400"></div>
                    <span>非常に高い (85%～)</span>
                  </div>
                </div>
              </div>
            </div>
          </ChartCard>
        </div>

        {/* Right Panel - Analytics */}
        <div className="col-span-4 space-y-6">
          {/* Selected Spot Details */}
          <div className="rounded-2xl border border-border bg-card p-6 shadow-sm">
            <div className="mb-4 flex items-start justify-between">
              <div>
                <h3 className="font-semibold text-foreground">工学部棟A</h3>
                <p className="text-sm text-muted-foreground">選択中のスポット</p>
              </div>
              <div className="rounded-lg bg-red-100 p-2 text-red-600">
                <AlertTriangle className="h-5 w-5" />
              </div>
            </div>
            
            <div className="space-y-4">
              <div>
                <div className="mb-1 flex items-center justify-between text-sm">
                  <span className="text-muted-foreground">現在人数</span>
                  <span className="text-2xl font-bold">184人</span>
                </div>
                <div className="h-2 overflow-hidden rounded-full bg-muted">
                  <div className="h-full w-[92%] rounded-full bg-red-500"></div>
                </div>
                <div className="mt-1 flex items-center justify-between text-xs text-muted-foreground">
                  <span>定員: 200人</span>
                  <span className="text-red-600">稼働率92%</span>
                </div>
              </div>

              <div className="flex items-center gap-2 text-sm">
                <TrendingUp className="h-4 w-4 text-red-600" />
                <span className="text-red-600">+12人 (過去15分)</span>
              </div>

              <div className="rounded-lg bg-red-50 border border-red-200 p-3">
                <div className="text-xs font-medium text-red-800 mb-1">混雑アラート</div>
                <div className="text-xs text-red-700">入場制限を推奨します</div>
              </div>
            </div>
          </div>

          {/* Visitor Composition */}
          <ChartCard title="来場者構成" subtitle="学科比率">
            <ResponsiveContainer width="100%" height={180}>
              <PieChart>
                <Pie
                  data={visitorComposition}
                  cx="50%"
                  cy="50%"
                  innerRadius={50}
                  outerRadius={70}
                  paddingAngle={2}
                  dataKey="value"
                >
                  {visitorComposition.map((entry, index) => (
                    <Cell key={`cell-${index}`} fill={entry.fill} />
                  ))}
                </Pie>
                <Tooltip
                  contentStyle={{
                    backgroundColor: 'white',
                    border: '1px solid #e5e7eb',
                    borderRadius: '8px',
                    boxShadow: '0 2px 8px rgba(0,0,0,0.1)',
                  }}
                />
              </PieChart>
            </ResponsiveContainer>
            <div className="mt-4 grid grid-cols-2 gap-2 text-xs">
              {visitorComposition.map((item, i) => (
                <div key={i} className="flex items-center gap-2">
                  <div className="h-3 w-3 rounded" style={{ backgroundColor: item.fill }}></div>
                  <span>{item.name}</span>
                  <span className="font-medium">{item.value}%</span>
                </div>
              ))}
            </div>
          </ChartCard>

          {/* Alerts */}
          <ChartCard title="アラート" subtitle="混雑・滞留・異常">
            <div className="space-y-3">
              {alerts.map((alert, i) => (
                <div
                  key={i}
                  className={`rounded-lg border p-3 ${
                    alert.severity === 'high'
                      ? 'border-red-200 bg-red-50'
                      : 'border-orange-200 bg-orange-50'
                  }`}
                >
                  <div className="mb-1 flex items-center justify-between">
                    <span className="text-xs font-medium text-primary">{alert.type}</span>
                    <span className="text-xs text-muted-foreground">{alert.location}</span>
                  </div>
                  <p className="text-xs">{alert.message}</p>
                </div>
              ))}
            </div>
          </ChartCard>
        </div>
      </div>

      {/* Bottom Section */}
      <div className="grid grid-cols-2 gap-6">
        {/* Stay Time */}
        <ChartCard title="スポット別滞在時間" subtitle="平均滞在時間（分）">
          <ResponsiveContainer width="100%" height={300}>
            <BarChart data={stayTimeData} layout="horizontal">
              <CartesianGrid strokeDasharray="3 3" stroke="#e5e7eb" />
              <XAxis type="number" stroke="#64748b" style={{ fontSize: '12px' }} />
              <YAxis type="category" dataKey="spot" stroke="#64748b" style={{ fontSize: '12px' }} width={100} />
              <Tooltip
                contentStyle={{
                  backgroundColor: 'white',
                  border: '1px solid #e5e7eb',
                  borderRadius: '8px',
                  boxShadow: '0 2px 8px rgba(0,0,0,0.1)',
                }}
              />
              <Bar dataKey="平均滞在時間" radius={[0, 8, 8, 0]}>
                {stayTimeData.map((entry, index) => (
                  <Cell key={`cell-${index}`} fill={index < 2 ? '#ef4444' : '#3b82f6'} />
                ))}
              </Bar>
            </BarChart>
          </ResponsiveContainer>
        </ChartCard>

        {/* Visitor Type */}
        <ChartCard title="来場者区分比率" subtitle="一般・学生・保護者">
          <div className="flex items-center justify-center">
            <ResponsiveContainer width="100%" height={300}>
              <PieChart>
                <Pie
                  data={visitorTypeData}
                  cx="50%"
                  cy="50%"
                  outerRadius={100}
                  label={({ name, value }) => `${name} ${value}%`}
                  dataKey="value"
                >
                  {visitorTypeData.map((entry, index) => (
                    <Cell key={`cell-${index}`} fill={entry.fill} />
                  ))}
                </Pie>
                <Tooltip
                  contentStyle={{
                    backgroundColor: 'white',
                    border: '1px solid #e5e7eb',
                    borderRadius: '8px',
                    boxShadow: '0 2px 8px rgba(0,0,0,0.1)',
                  }}
                />
              </PieChart>
            </ResponsiveContainer>
          </div>
        </ChartCard>
      </div>
    </div>
  );
}
