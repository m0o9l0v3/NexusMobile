import { Search, Bell, ChevronDown } from 'lucide-react';
import { clearAdminSession } from '../auth/session';

export function Header() {
  return (
    <header className="sticky top-0 z-30 border-b border-border bg-card/80 backdrop-blur-sm">
      <div className="flex h-16 items-center gap-4 px-6">
        {/* Title */}
        <div className="flex-1">
          <h1 className="text-xl font-semibold text-foreground">Nexus 管理ポータル</h1>
        </div>

        {/* Open Campus Selector */}
        <div className="flex items-center gap-2">
          <select className="rounded-lg border border-border bg-card px-3 py-1.5 text-sm focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary/20">
            <option>2026年1月オープンキャンパス</option>
            <option>2025年12月オープンキャンパス</option>
            <option>2025年11月オープンキャンパス</option>
          </select>
        </div>

        {/* Date Range Selector */}
        <div className="flex items-center gap-2">
          <button className="rounded-lg border border-border bg-card px-3 py-1.5 text-sm hover:bg-accent">
            今日
          </button>
          <button className="rounded-lg border border-border bg-card px-3 py-1.5 text-sm hover:bg-accent">
            過去7日間
          </button>
          <button className="rounded-lg border border-border bg-card px-3 py-1.5 text-sm hover:bg-accent">
            カスタム
          </button>
        </div>

        {/* Search */}
        <div className="relative">
          <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
          <input
            type="search"
            placeholder="検索..."
            className="w-64 rounded-lg border border-border bg-card py-1.5 pl-9 pr-3 text-sm focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary/20"
          />
        </div>

        {/* Notifications */}
        <button className="relative rounded-lg p-2 hover:bg-accent">
          <Bell className="h-5 w-5" />
          <span className="absolute right-1 top-1 h-2 w-2 rounded-full bg-destructive"></span>
        </button>

        {/* User Profile */}
        <button className="flex items-center gap-2 rounded-lg border border-border bg-card px-3 py-1.5 hover:bg-accent">
          <div className="h-7 w-7 rounded-full bg-primary text-xs text-primary-foreground flex items-center justify-center">
            管
          </div>
          <span className="text-sm">管理者</span>
          <ChevronDown className="h-4 w-4 text-muted-foreground" />
        </button>
        <button type="button" onClick={() => clearAdminSession()} className="min-h-11 rounded-2xl border border-border bg-card px-3 py-2 text-sm hover:bg-accent focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary">
          ログアウト
        </button>
      </div>
    </header>
  );
}
