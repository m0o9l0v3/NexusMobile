import { NavLink } from 'react-router-dom';
import {
  LayoutDashboard,
  MapPin,
  Calendar,
  CalendarDays,
  QrCode,
  ScrollText,
  Settings,
} from 'lucide-react';

const navigation = [
  { name: 'ダッシュボード', icon: LayoutDashboard, path: '/' },
  { name: 'スポット管理', icon: MapPin, path: '/spots' },
  { name: 'イベント管理', icon: Calendar, path: '/events' },
  { name: 'オープンキャンパス日程', icon: CalendarDays, path: '/schedule' },
  { name: 'QR発行', icon: QrCode, path: '/qr' },
  { name: 'ログ', icon: ScrollText, path: '/logs' },
  { name: '設定', icon: Settings, path: '/settings' },
];

export function Sidebar() {
  return (
    <aside className="fixed left-0 top-0 z-40 h-screen w-20 border-r border-sidebar-border bg-sidebar">
      <div className="flex h-full flex-col items-center py-6">
        {/* Logo */}
        <div className="mb-8 flex h-12 w-12 items-center justify-center rounded-xl bg-primary text-primary-foreground">
          <span className="text-xl font-bold">N</span>
        </div>

        {/* Navigation */}
        <nav className="flex flex-1 flex-col gap-2">
          {navigation.map((item) => {
            const Icon = item.icon;
            return (
              <NavLink
                key={item.path}
                to={item.path}
                className={({ isActive }) =>
                  `group relative flex h-12 w-12 flex-col items-center justify-center gap-0.5 rounded-lg transition-colors ${
                    isActive
                      ? 'bg-sidebar-accent text-sidebar-primary'
                      : 'text-sidebar-foreground/60 hover:bg-sidebar-accent/50 hover:text-sidebar-foreground'
                  }`
                }
              >
                <Icon className="h-5 w-5" />
                <span className="pointer-events-none absolute left-full ml-2 w-max rounded-lg bg-sidebar-foreground px-2 py-1 text-xs text-sidebar opacity-0 shadow-lg transition-opacity group-hover:opacity-100">
                  {item.name}
                </span>
              </NavLink>
            );
          })}
        </nav>
      </div>
    </aside>
  );
}
