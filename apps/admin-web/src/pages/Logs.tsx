import { useMemo, useState } from 'react';
import { Search, X } from 'lucide-react';
import { ChartCard } from '../components/ChartCard';

const logs = [
  { id: 'QR-2026-001234', time: '2026-01-28 15:42:15', type: 'ENTRY', visitorType: 'STUDENT', gate: 'EAST', spot: 'PC Room', action: 'IN', status: 'SUCCESS' },
  { id: 'QR-2026-001235', time: '2026-01-28 15:41:52', type: 'EXIT', visitorType: 'PARENT', gate: 'EAST', spot: 'CTC', action: 'OUT', status: 'SUCCESS' },
  { id: 'QR-2026-001236', time: '2026-01-28 15:40:33', type: 'ERROR', visitorType: '-', gate: 'WEST', spot: '-', action: 'ERROR', status: 'FAILED' },
];

export function Logs() {
  const [search, setSearch] = useState('');
  const [selectedLog, setSelectedLog] = useState<(typeof logs)[number] | null>(null);

  const filteredLogs = useMemo(() => {
    const keyword = search.trim().toLowerCase();
    if (!keyword) return logs;
    return logs.filter((log) => Object.values(log).some((value) => value.toLowerCase().includes(keyword)));
  }, [search]);

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-2xl font-semibold text-foreground">Logs</h2>
        <p className="mt-1 text-sm text-muted-foreground">Browse gate activity and check-in records.</p>
      </div>

      <div className="rounded-2xl border border-border bg-card p-4 shadow-sm">
        <div className="relative max-w-md">
          <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
          <input
            type="text"
            value={search}
            onChange={(event) => setSearch(event.target.value)}
            placeholder="Search by QR ID, type, gate, or spot"
            className="w-full rounded-lg border border-border bg-input-background py-2 pl-9 pr-3 text-sm focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary/20"
          />
        </div>
      </div>

      <ChartCard title="Activity Table" subtitle={`${filteredLogs.length} rows`}>
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead className="border-b border-border bg-muted/50 text-left">
              <tr>
                <th className="px-4 py-3 font-medium">Time</th>
                <th className="px-4 py-3 font-medium">Type</th>
                <th className="px-4 py-3 font-medium">Visitor</th>
                <th className="px-4 py-3 font-medium">QR ID</th>
                <th className="px-4 py-3 font-medium">Gate</th>
                <th className="px-4 py-3 font-medium">Spot</th>
                <th className="px-4 py-3 font-medium">Status</th>
              </tr>
            </thead>
            <tbody>
              {filteredLogs.map((log) => (
                <tr
                  key={log.id}
                  onClick={() => setSelectedLog(log)}
                  className="cursor-pointer border-b border-border hover:bg-muted/30"
                >
                  <td className="px-4 py-3">{log.time}</td>
                  <td className="px-4 py-3">{log.type}</td>
                  <td className="px-4 py-3">{log.visitorType}</td>
                  <td className="px-4 py-3 font-mono text-xs text-primary">{log.id}</td>
                  <td className="px-4 py-3">{log.gate}</td>
                  <td className="px-4 py-3">{log.spot}</td>
                  <td className="px-4 py-3">
                    <span className={log.status === 'SUCCESS' ? 'text-green-600' : 'text-red-600'}>{log.status}</span>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </ChartCard>

      {selectedLog && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4" onClick={() => setSelectedLog(null)}>
          <div className="w-full max-w-lg rounded-2xl border border-border bg-card p-6 shadow-2xl" onClick={(event) => event.stopPropagation()}>
            <div className="mb-4 flex items-start justify-between">
              <div>
                <h3 className="text-lg font-semibold">Log Detail</h3>
                <p className="text-sm text-muted-foreground">{selectedLog.id}</p>
              </div>
              <button onClick={() => setSelectedLog(null)} className="rounded-lg p-1 hover:bg-muted">
                <X className="h-5 w-5" />
              </button>
            </div>

            <div className="grid grid-cols-2 gap-4 rounded-lg bg-muted/30 p-4 text-sm">
              <div>
                <div className="mb-1 text-xs text-muted-foreground">Time</div>
                <div>{selectedLog.time}</div>
              </div>
              <div>
                <div className="mb-1 text-xs text-muted-foreground">Type</div>
                <div>{selectedLog.type}</div>
              </div>
              <div>
                <div className="mb-1 text-xs text-muted-foreground">Visitor</div>
                <div>{selectedLog.visitorType}</div>
              </div>
              <div>
                <div className="mb-1 text-xs text-muted-foreground">Gate</div>
                <div>{selectedLog.gate}</div>
              </div>
              <div>
                <div className="mb-1 text-xs text-muted-foreground">Spot</div>
                <div>{selectedLog.spot}</div>
              </div>
              <div>
                <div className="mb-1 text-xs text-muted-foreground">Status</div>
                <div>{selectedLog.status}</div>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
