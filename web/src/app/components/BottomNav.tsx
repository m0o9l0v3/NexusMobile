import { motion } from 'motion/react';
import { Home, Calendar } from 'lucide-react';
import { MapSearchIcon } from '@/app/components/MapSearchIcon';

type NavItem = {
  id: string;
  label: string;
  icon: React.ReactNode;
  isHero?: boolean;
};

type BottomNavProps = {
  activeTab: string;
  onTabChange: (tab: string) => void;
};

const navItems: NavItem[] = [
  { id: 'home', label: 'ホーム', icon: <Home size={22} /> },
  { id: 'map', label: 'マップ', icon: <MapSearchIcon size={22} />, isHero: true },
  { id: 'events', label: 'イベント', icon: <Calendar size={22} /> },
];

export function BottomNav({ activeTab, onTabChange }: BottomNavProps) {
  return (
    <div 
      className="fixed left-0 right-0 z-50 border-t"
      style={{
        backgroundColor: 'var(--surface)',
        borderColor: 'var(--outline)',
        bottom: 0,
        paddingBottom: 'max(8px, env(safe-area-inset-bottom))',
      }}
    >
      <div className="flex items-end justify-around px-4 py-2 relative">
        {navItems.map((item) => {
          const isActive = item.id === activeTab;
          const isMapTab = item.isHero;
          
          // Map tab is elevated when on Map screen, subtle on Home/Events
          const isMapActive = isMapTab && isActive;
          const shouldElevate = isMapActive;
          
          return (
            <motion.button
              key={item.id}
              onClick={() => onTabChange(item.id)}
              className="flex flex-col items-center justify-center gap-1 py-2 px-6 transition-colors flex-1 relative"
              style={{
                color: isActive ? 'var(--primary)' : 'var(--muted-foreground)',
                opacity: isMapTab && !isActive ? 0.8 : (isActive ? 1 : 0.6),
              }}
              animate={shouldElevate ? {
                y: -6,
                scale: 1.08,
              } : {
                y: 0,
                scale: 1,
              }}
              transition={{
                type: 'spring',
                stiffness: 300,
                damping: 25,
              }}
            >
              {/* Hero Map button with circular elevated background - only when active */}
              {shouldElevate && (
                <motion.div
                  className="absolute rounded-full"
                  style={{
                    backgroundColor: 'var(--surface)',
                    boxShadow: 'var(--elev-3)',
                    width: '64px',
                    height: '64px',
                    top: '50%',
                    left: '50%',
                    marginTop: '-32px',
                    marginLeft: '-32px',
                  }}
                  initial={{ opacity: 0, scale: 0.8 }}
                  animate={{ opacity: 1, scale: 1 }}
                  transition={{
                    type: 'spring',
                    stiffness: 300,
                    damping: 25,
                  }}
                />
              )}
              
              <div 
                className="flex flex-col items-center gap-1 relative z-10"
                style={{
                  color: isMapTab ? 'var(--primary)' : (isActive ? 'var(--primary)' : 'var(--muted-foreground)'),
                }}
              >
                {item.icon}
                <span className="text-[11px] font-medium">
                  {item.label}
                </span>
              </div>
            </motion.button>
          );
        })}
      </div>
    </div>
  );
}
