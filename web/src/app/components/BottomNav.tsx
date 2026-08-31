import navHomeIcon from '@/assets/map/nav-home.svg';
import navInfoIcon from '@/assets/map/nav-info.svg';
import navMapIcon from '@/assets/map/nav-map-active.svg';
import navScheduleIcon from '@/assets/map/nav-schedule.svg';

export type BottomNavItemId = 'home' | 'map' | 'info' | 'schedule';

type BottomNavProps = {
  activeTab: BottomNavItemId | 'events';
  onTabChange: (tab: BottomNavItemId) => void;
};

const navItems: Array<{ id: BottomNavItemId; label: string; icon: string; iconSize: number }> = [
  { id: 'home', label: 'ホーム', icon: navHomeIcon, iconSize: 32 },
  { id: 'map', label: 'マップ', icon: navMapIcon, iconSize: 32 },
  { id: 'info', label: '情報', icon: navInfoIcon, iconSize: 29 },
  { id: 'schedule', label: '時間割', icon: navScheduleIcon, iconSize: 32 },
];

export function BottomNav({ activeTab, onTabChange }: BottomNavProps) {
  return (
    <nav
      className="fixed left-1/2 z-50 h-[72px] w-[calc(100%_-_43px)] max-w-[350px] -translate-x-1/2 overflow-hidden rounded-[28px] border border-white/80 bg-white/90 backdrop-blur-xl"
      style={{
        bottom: 'calc(env(safe-area-inset-bottom, 0px) + 10px)',
        boxShadow: '0 4px 16px rgba(0, 0, 0, 0.12)',
      }}
      aria-label="メインナビゲーション"
    >
      <div className="flex h-full items-stretch px-1.5">
        {navItems.map((item) => {
          const isActive = item.id === activeTab;

          return (
            <button
              key={item.id}
              type="button"
              onClick={() => onTabChange(item.id)}
              className="relative flex min-w-0 flex-1 flex-col items-center justify-start rounded-[24px] pt-[7px]"
              aria-current={isActive ? 'page' : undefined}
              aria-label={item.id === 'info' || item.id === 'schedule' ? `${item.label}（準備中）` : item.label}
            >
              {isActive && (
                <span className="absolute inset-y-0 left-0 right-0 rounded-[24px] bg-black/[0.055]" aria-hidden="true" />
              )}
              <img
                src={item.icon}
                alt=""
                className="relative z-10 block shrink-0"
                style={{
                  width: `${item.iconSize}px`,
                  height: `${item.iconSize}px`,
                }}
                aria-hidden="true"
              />
              <span
                className="relative z-10 -mt-0.5 text-[10px] font-medium leading-3"
                style={{
                  color: isActive ? '#007aff' : '#000000',
                  fontFamily: '-apple-system, BlinkMacSystemFont, "Noto Sans JP", "Inter", sans-serif',
                }}
              >
                {item.label}
              </span>
            </button>
          );
        })}
      </div>
    </nav>
  );
}
