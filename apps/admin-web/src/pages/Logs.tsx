import { useState } from 'react';
import { Download, FileJson, Printer, Search, ChevronDown, Calendar, X } from 'lucide-react';
import { ChartCard } from '../components/ChartCard';
import { AreaChart, Area, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from 'recharts';

// Mock data
const logs = [
  { id: 'QR-2026-001234', time: '2026-01-28 15:42:15', type: '入場', visitorType: '一般来場者', gate: 'ゲートA', spot: 'PC教室', action: 'IN', status: '正常' },
  { id: 'QR-2026-001235', time: '2026-01-28 15:41:52', type: '退場', visitorType: '高校生', gate: 'ゲートB', spot: '図書館', action: 'OUT', status: '正常' },
  { id: 'QR-2026-001236', time: '2026-01-28 15:40:33', type: '入場', visitorType: '保護者', gate: 'ゲートA', spot: '食堂', action: 'IN', status: '正常' },
  { id: 'QR-2026-001237', time: '2026-01-28 15:39:48', type: 'エラー', visitorType: '-', gate: 'ゲートC', spot: '-', action: 'ERROR', status: 'QR無効' },
  { id: 'QR-2026-001238', time: '2026-01-28 15:38:12', type: '入場', visitorType: '高校生', gate: 'ゲートA', spot: 'PC教室', action: 'IN', status: '正常' },
  { id: 'QR-2026-001239', time: '2026-01-28 15:37:45', type: '入場', visitorType: '一般来場者', gate: 'ゲートB', spot: '体育館', action: 'IN', status: '正常' },
  { id: 'QR-2026-001240', time: '2026-01-28 15:36:28', type: '退場', visitorType: '保護者', gate: 'ゲートA', spot: 'CTC', action: 'OUT', status: '正常' },
  { id: 'QR-2026-001241', time: '2026-01-28 15:35:19', type: '入場', visitorType: '高校生', gate: 'ゲートC', spot: '格納庫', action: 'IN', status: '正常' },
  { id: 'QR-2026-001242', time: '2026-01-28 15:34:52', type: 'エラー', visitorType: '-', gate: 'ゲートA', spot: '-', action: 'ERROR', status: '期限切れ' },
  { id: 'QR-2026-001243', time: '2026-01-28 15:33:41', type: '入場', visitorType: '一般来場者', gate: 'ゲートB', spot: 'PC教室', action: 'IN', status: '正常' },
  { id: 'QR-2026-001244', time: '2026-01-28 15:32:18', type: '入場', visitorType: '高校生', gate: 'ゲートA', spot: '食堂', action: 'IN', status: '正常' },
  { id: 'QR-2026-001245', time: '2026-01-28 15:31:05', type: '退場', visitorType: '保護者', gate: 'ゲートC', spot: '体育館', action: 'OUT', status: '正常' },
];

const activityData = [
  { time: '09:00', アクティビティ: 12 },
  { time: '10:00', アクティビティ: 45 },
  { time: '11:00', アクティビティ: 78 },
  { time: '12:00', アクティビティ: 98 },
  { time: '13:00', アクティビティ: 85 },
  { time: '14:00', アクティビティ: 92 },
  { time: '15:00', アクティビティ: 67 },
  { time: '16:00', アクティビティ: 34 },
];

export function Logs() {
  const [selectedLog, setSelectedLog] = useState<typeof logs[0] | null>(null);
  const [filters, setFilters] = useState({
    type: '',
    visitorType: '',
    spot: '',
    status: '',
    search: '',
  });

  const filteredLogs = logs.filter((log) => {
    if (filters.type && log.type !== filters.type) return false;
    if (filters.visitorType && log.visitorType !== filters.visitorType) return false;
    if (filters.spot && log.spot !== filters.spot) return false;
    if (filters.status && log.status !== filters.status) return false;
    if (filters.search && !log.id.toLowerCase().includes(filters.search.toLowerCase())) return false;
    return true;
  });

  const totalRecords = filteredLogs.length;
  const errorRate = (filteredLogs.filter((log) => log.status !== '正常').length / totalRecords * 100).toFixed(1);
  const mostUsedGate = 'ゲートA';
  const peakTime = '12:00-13:00';

  return (
    <div className="space-y-6">
      {/* Page Header */}
      <div>
        <h2 className="text-2xl font-semibold text-foreground">ログ / データ</h2>
        <p className="text-sm text-muted-foreground mt-1">
          チェックイン記録とアクティビティログを管理
        </p>
      </div>

      {/* Filter Bar */}
      <div className="rounded-2xl border border-border bg-card p-4 shadow-sm">
        <div className="flex flex-wrap items-center gap-3">
          {/* Search */}
          <div className="relative flex-1 min-w-[240px]">
            <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
            <input
              type="text"
              placeholder="QR IDで検索..."
              className="w-full rounded-lg border border-border bg-input-background py-2 pl-9 pr-3 text-sm focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary/20"
              value={filters.search}
              onChange={(e) => setFilters({ ...filters, search: e.target.value })}
            />
          </div>

          {/* Date Range */}
          <div className="flex items-center gap-2">
            <Calendar className="h-4 w-4 text-muted-foreground" />
            <input
              type="date"
              defaultValue="2026-01-28"
              className="rounded-lg border border-border bg-input-background px-3 py-1.5 text-sm focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary/20"
            />
            <span className="text-sm text-muted-foreground">～</span>
            <input
              type="date"
              defaultValue="2026-01-28"
              className="rounded-lg border border-border bg-input-background px-3 py-1.5 text-sm focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary/20"
            />
          </div>

          {/* Type Filter */}
          <select
            className="rounded-lg border border-border bg-input-background px-3 py-1.5 text-sm focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary/20"
            value={filters.type}
            onChange={(e) => setFilters({ ...filters, type: e.target.value })}
          >
            <option value="">全てのタイプ</option>
            <option value="入場">入場</option>
            <option value="退場">退場</option>
            <option value="エラー">エラー</option>
          </select>

          {/* Visitor Type Filter */}
          <select
            className="rounded-lg border border-border bg-input-background px-3 py-1.5 text-sm focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary/20"
            value={filters.visitorType}
            onChange={(e) => setFilters({ ...filters, visitorType: e.target.value })}
          >
            <option value="">全ての来場者</option>
            <option value="高校生">高校生</option>
            <option value="保護者">保護者</option>
            <option value="一般来場者">一般来場者</option>
          </select>

          {/* Status Filter */}
          <select
            className="rounded-lg border border-border bg-input-background px-3 py-1.5 text-sm focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary/20"
            value={filters.status}
            onChange={(e) => setFilters({ ...filters, status: e.target.value })}
          >
            <option value="">全てのステータス</option>
            <option value="正常">正常</option>
            <option value="QR無効">QR無効</option>
            <option value="期限切れ">期限切れ</option>
          </select>

          {/* Clear Filters */}
          {(filters.type || filters.visitorType || filters.status || filters.search) && (
            <button
              onClick={() => setFilters({ type: '', visitorType: '', spot: '', status: '', search: '' })}
              className="flex items-center gap-1 rounded-lg border border-border px-3 py-1.5 text-sm hover:bg-accent"
            >
              <X className="h-4 w-4" />
              クリア
            </button>
          )}

          {/* Export Actions */}
          <div className="ml-auto flex gap-2">
            <button className="flex items-center gap-2 rounded-lg border border-border bg-card px-3 py-1.5 text-sm hover:bg-accent">
              <Download className="h-4 w-4" />
              CSV
            </button>
            <button className="flex items-center gap-2 rounded-lg border border-border bg-card px-3 py-1.5 text-sm hover:bg-accent">
              <FileJson className="h-4 w-4" />
              JSON
            </button>
            <button className="flex items-center gap-2 rounded-lg border border-border bg-card px-3 py-1.5 text-sm hover:bg-accent">
              <Printer className="h-4 w-4" />
              印刷
            </button>
          </div>
        </div>
      </div>

      <div className="grid grid-cols-12 gap-6">
        {/* Main Table */}
        <div className="col-span-9">
          <div className="rounded-2xl border border-border bg-card shadow-sm overflow-hidden">
            {/* Table Header */}
            <div className="border-b border-border bg-gradient-to-br from-white/60 to-transparent p-4">
              <div className="flex items-center justify-between">
                <div>
                  <h3 className="font-semibold">チェックイン記録</h3>
                  <p className="text-sm text-muted-foreground mt-0.5">
                    {totalRecords}件のレコード
                  </p>
                </div>
              </div>
            </div>

            {/* Table */}
            <div className="overflow-x-auto">
              <table className="w-full">
                <thead className="sticky top-0 bg-muted/50 text-xs border-b border-border">
                  <tr>
                    <th className="px-4 py-3 text-left font-medium cursor-pointer hover:bg-muted/70">
                      <div className="flex items-center gap-1">
                        時刻
                        <ChevronDown className="h-3 w-3" />
                      </div>
                    </th>
                    <th className="px-4 py-3 text-left font-medium cursor-pointer hover:bg-muted/70">
                      <div className="flex items-center gap-1">
                        タイプ
                        <ChevronDown className="h-3 w-3" />
                      </div>
                    </th>
                    <th className="px-4 py-3 text-left font-medium cursor-pointer hover:bg-muted/70">
                      <div className="flex items-center gap-1">
                        来場者区分
                        <ChevronDown className="h-3 w-3" />
                      </div>
                    </th>
                    <th className="px-4 py-3 text-left font-medium cursor-pointer hover:bg-muted/70">
                      <div className="flex items-center gap-1">
                        QR ID
                        <ChevronDown className="h-3 w-3" />
                      </div>
                    </th>
                    <th className="px-4 py-3 text-left font-medium cursor-pointer hover:bg-muted/70">
                      <div className="flex items-center gap-1">
                        ゲート
                        <ChevronDown className="h-3 w-3" />
                      </div>
                    </th>
                    <th className="px-4 py-3 text-left font-medium cursor-pointer hover:bg-muted/70">
                      <div className="flex items-center gap-1">
                        スポット
                        <ChevronDown className="h-3 w-3" />
                      </div>
                    </th>
                    <th className="px-4 py-3 text-left font-medium cursor-pointer hover:bg-muted/70">
                      <div className="flex items-center gap-1">
                        アクション
                        <ChevronDown className="h-3 w-3" />
                      </div>
                    </th>
                    <th className="px-4 py-3 text-left font-medium cursor-pointer hover:bg-muted/70">
                      <div className="flex items-center gap-1">
                        ステータス
                        <ChevronDown className="h-3 w-3" />
                      </div>
                    </th>
                  </tr>
                </thead>
                <tbody className="text-sm">
                  {filteredLogs.map((log) => (
                    <tr
                      key={log.id}
                      onClick={() => setSelectedLog(log)}
                      className="border-t border-border hover:bg-muted/30 cursor-pointer transition-colors"
                    >
                      <td className="px-4 py-3 text-muted-foreground">{log.time}</td>
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
                      <td className="px-4 py-3">{log.visitorType}</td>
                      <td className="px-4 py-3 font-mono text-xs text-primary">{log.id}</td>
                      <td className="px-4 py-3 text-muted-foreground">{log.gate}</td>
                      <td className="px-4 py-3">{log.spot}</td>
                      <td className="px-4 py-3">
                        <span className="font-mono text-xs">{log.action}</span>
                      </td>
                      <td className="px-4 py-3">
                        <span
                          className={`text-xs font-medium ${
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

            {/* Pagination */}
            <div className="border-t border-border bg-muted/30 px-4 py-3">
              <div className="flex items-center justify-between text-sm">
                <div className="text-muted-foreground">
                  全{totalRecords}件中 1-{Math.min(12, totalRecords)}件を表示
                </div>
                <div className="flex gap-2">
                  <button className="rounded border border-border bg-card px-3 py-1 hover:bg-accent disabled:opacity-50" disabled>
                    前へ
                  </button>
                  <button className="rounded border border-border bg-card px-3 py-1 hover:bg-accent">
                    次へ
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* Right Insights Panel */}
        <div className="col-span-3 space-y-6">
          {/* Quick Stats */}
          <div className="rounded-2xl border border-border bg-card p-4 shadow-sm">
            <h3 className="font-semibold mb-4">クイック統計</h3>
            <div className="space-y-4">
              <div>
                <div className="text-sm text-muted-foreground mb-1">総レコード数</div>
                <div className="text-2xl font-bold">{totalRecords}</div>
              </div>
              <div>
                <div className="text-sm text-muted-foreground mb-1">エラー率</div>
                <div className="flex items-baseline gap-2">
                  <div className="text-2xl font-bold text-red-600">{errorRate}%</div>
                  <div className="text-xs text-muted-foreground">
                    {filteredLogs.filter((log) => log.status !== '正常').length}件
                  </div>
                </div>
              </div>
              <div>
                <div className="text-sm text-muted-foreground mb-1">最多使用ゲート</div>
                <div className="text-lg font-semibold">{mostUsedGate}</div>
              </div>
              <div>
                <div className="text-sm text-muted-foreground mb-1">ピーク時間</div>
                <div className="text-lg font-semibold">{peakTime}</div>
              </div>
            </div>
          </div>

          {/* Activity Chart */}
          <ChartCard title="アクティビティ推移" subtitle="時間帯別">
            <ResponsiveContainer width="100%" height={150}>
              <AreaChart data={activityData}>
                <defs>
                  <linearGradient id="colorActivity" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor="#2563eb" stopOpacity={0.3} />
                    <stop offset="95%" stopColor="#2563eb" stopOpacity={0} />
                  </linearGradient>
                </defs>
                <CartesianGrid strokeDasharray="3 3" stroke="#e5e7eb" />
                <XAxis dataKey="time" stroke="#64748b" style={{ fontSize: '10px' }} />
                <YAxis stroke="#64748b" style={{ fontSize: '10px' }} />
                <Tooltip
                  contentStyle={{
                    backgroundColor: 'white',
                    border: '1px solid #e5e7eb',
                    borderRadius: '8px',
                    fontSize: '12px',
                  }}
                />
                <Area type="monotone" dataKey="アクティビティ" stroke="#2563eb" fillOpacity={1} fill="url(#colorActivity)" />
              </AreaChart>
            </ResponsiveContainer>
          </ChartCard>
        </div>
      </div>

      {/* Detail Drawer Modal */}
      {selectedLog && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm" onClick={() => setSelectedLog(null)}>
          <div className="w-full max-w-lg rounded-2xl border border-border bg-card p-6 shadow-2xl" onClick={(e) => e.stopPropagation()}>
            <div className="mb-4 flex items-start justify-between">
              <div>
                <h3 className="text-lg font-semibold">レコード詳細</h3>
                <p className="text-sm text-muted-foreground">ID: {selectedLog.id}</p>
              </div>
              <button onClick={() => setSelectedLog(null)} className="rounded-lg p-1 hover:bg-muted">
                <X className="h-5 w-5" />
              </button>
            </div>

            <div className="space-y-4">
              <div className="grid grid-cols-2 gap-4 rounded-lg bg-muted/30 p-4">
                <div>
                  <div className="text-xs text-muted-foreground mb-1">タイムスタンプ</div>
                  <div className="text-sm font-medium">{selectedLog.time}</div>
                </div>
                <div>
                  <div className="text-xs text-muted-foreground mb-1">アクションタイプ</div>
                  <span
                    className={`inline-flex rounded-full px-2 py-0.5 text-xs font-medium ${
                      selectedLog.type === '入場'
                        ? 'bg-green-100 text-green-700'
                        : selectedLog.type === '退場'
                        ? 'bg-blue-100 text-blue-700'
                        : 'bg-red-100 text-red-700'
                    }`}
                  >
                    {selectedLog.type}
                  </span>
                </div>
                <div>
                  <div className="text-xs text-muted-foreground mb-1">来場者区分</div>
                  <div className="text-sm font-medium">{selectedLog.visitorType}</div>
                </div>
                <div>
                  <div className="text-xs text-muted-foreground mb-1">ゲート</div>
                  <div className="text-sm font-medium">{selectedLog.gate}</div>
                </div>
                <div>
                  <div className="text-xs text-muted-foreground mb-1">スポット</div>
                  <div className="text-sm font-medium">{selectedLog.spot}</div>
                </div>
                <div>
                  <div className="text-xs text-muted-foreground mb-1">ステータス</div>
                  <span
                    className={`text-sm font-medium ${
                      selectedLog.status === '正常' ? 'text-green-600' : 'text-red-600'
                    }`}
                  >
                    {selectedLog.status}
                  </span>
                </div>
              </div>

              <div className="rounded-lg border border-border bg-muted/30 p-4">
                <div className="text-xs font-medium mb-2">タイムライン</div>
                <div className="space-y-2">
                  <div className="flex items-center gap-2 text-xs">
                    <div className="h-2 w-2 rounded-full bg-blue-500"></div>
                    <span className="text-muted-foreground">{selectedLog.time}</span>
                    <span>QRスキャン実行</span>
                  </div>
                  <div className="flex items-center gap-2 text-xs">
                    <div className="h-2 w-2 rounded-full bg-green-500"></div>
                    <span className="text-muted-foreground">{selectedLog.time}</span>
                    <span>認証完了</span>
                  </div>
                  <div className="flex items-center gap-2 text-xs">
                    <div className="h-2 w-2 rounded-full bg-green-500"></div>
                    <span className="text-muted-foreground">{selectedLog.time}</span>
                    <span>ログ記録完了</span>
                  </div>
                </div>
              </div>
            </div>

            <div className="mt-6 flex gap-2">
              <button className="flex-1 rounded-lg border border-border px-4 py-2 text-sm hover:bg-accent">
                詳細ログ
              </button>
              <button onClick={() => setSelectedLog(null)} className="flex-1 rounded-lg bg-primary px-4 py-2 text-sm text-primary-foreground hover:bg-primary/90">
                閉じる
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
