import { motion } from 'motion/react';
import { MapPin, Calendar, ChevronRight, Map as MapIcon, ArrowRight } from 'lucide-react';
import { CongestionBadge } from '@/app/components/CongestionBadge';
import { MapHeroCard } from '@/app/components/MapHeroCard';

type Event = {
  id: string;
  title: string;
  time: string;
  location: string;
  department: string;
};

type Spot = {
  id: string;
  name: string;
  category: string;
  congestion: 'empty' | 'normal' | 'busy' | 'full';
  floor: string;
};

type HomeScreenProps = {
  onOpenMap: () => void;
  onEventClick: (event: Event) => void;
  onSpotClick: (spot: Spot) => void;
};

const upcomingEvents: Event[] = [
  {
    id: '1',
    title: '工学部説明会',
    time: '11:00',
    location: '講義室A',
    department: '工学部',
  },
  {
    id: '2',
    title: 'キャンパスツアー',
    time: '11:30',
    location: '受付集合',
    department: '全体',
  },
  {
    id: '3',
    title: '模擬授業：AI入門',
    time: '13:00',
    location: '実験室B',
    department: '情報学部',
  },
];

type RecommendedSpot = Spot & {
  reason: string;
};

const recommendedSpots: RecommendedSpot[] = [
  {
    id: '1',
    name: '図書館',
    category: '施設見学',
    congestion: 'empty',
    floor: '2F',
    reason: '静かに見学できます',
  },
  {
    id: '2',
    name: 'カフェテリア',
    category: '休憩',
    congestion: 'normal',
    floor: '2F',
    reason: '休憩におすすめ',
  },
  {
    id: '3',
    name: '研究室',
    category: '体験',
    congestion: 'busy',
    floor: '3F',
    reason: '最新研究を見学',
  },
];

export function HomeScreen({ onOpenMap, onEventClick, onSpotClick }: HomeScreenProps) {
  return (
    <div className="h-full overflow-y-auto pb-bottom-nav">
      {/* Hero section */}
      <div 
        className="px-4 pt-8 pb-6 bg-gradient-to-b"
        style={{
          background: 'linear-gradient(180deg, var(--sky-1) 0%, var(--sky-0) 100%)',
        }}
      >
        <div className="mb-3">
          <h1 className="mb-1" style={{ color: 'var(--text)' }}>
            Nexus
          </h1>
          <p className="text-sm" style={{ color: 'var(--muted-foreground)' }}>
            オープンキャンパスへようこそ
          </p>
        </div>
        
        {/* Map Hero Card */}
        <MapHeroCard onOpenMap={onOpenMap} />
      </div>
      
      {/* Next Events section */}
      <section className="px-4 py-6">
        <div className="flex items-center justify-between mb-4">
          <h2 className="flex items-center gap-2" style={{ color: 'var(--text)' }}>
            <Calendar size={18} style={{ color: 'var(--text)', opacity: 0.4 }} />
            次のイベント
          </h2>
        </div>
        
        <div className="space-y-3">
          {upcomingEvents.map((event) => (
            <motion.div
              key={event.id}
              className="p-4 rounded-2xl cursor-pointer"
              style={{
                backgroundColor: 'var(--surface)',
                boxShadow: 'var(--elev-1)',
              }}
              onClick={() => onEventClick(event)}
              whileTap={{ scale: 0.98 }}
            >
              <div className="flex items-start gap-3">
                <div 
                  className="px-3 py-1 rounded-full text-xs font-medium tabular-nums flex-shrink-0"
                  style={{
                    backgroundColor: 'var(--primary-weak)',
                    color: 'var(--primary)',
                  }}
                >
                  {event.time}
                </div>
                <div className="flex-1 min-w-0">
                  <div className="font-medium mb-1" style={{ color: 'var(--text)' }}>
                    {event.title}
                  </div>
                  <div className="flex items-center gap-2 text-xs mb-2" style={{ color: 'var(--muted-foreground)' }}>
                    <MapPin size={12} />
                    <span>{event.location}</span>
                    <span>·</span>
                    <span>{event.department}</span>
                  </div>
                  
                  {/* Text link */}
                  <button
                    onClick={(e) => {
                      e.stopPropagation();
                      onOpenMap();
                    }}
                    className="inline-flex items-center gap-1 text-xs transition-opacity hover:opacity-70"
                    style={{ color: 'var(--primary)' }}
                  >
                    <MapIcon size={12} />
                    <span>マップで場所を見る</span>
                    <ArrowRight size={12} />
                  </button>
                </div>
              </div>
            </motion.div>
          ))}
        </div>
      </section>
      
      {/* Recommended Spots section */}
      <section className="px-4 pb-6">
        <div className="flex items-center justify-between mb-4">
          <h2 className="flex items-center gap-2" style={{ color: 'var(--text)' }}>
            <MapPin size={18} style={{ color: 'var(--text)', opacity: 0.4 }} />
            おすすめスポット
          </h2>
        </div>
        
        <div className="space-y-3">
          {recommendedSpots.map((spot) => (
            <div
              key={spot.id}
              className="p-4 rounded-2xl"
              style={{
                backgroundColor: 'var(--surface)',
                boxShadow: 'var(--elev-1)',
              }}
            >
              <div className="flex items-start justify-between">
                <div className="flex items-start gap-3 flex-1">
                  <div 
                    className="w-10 h-10 rounded-xl flex items-center justify-center flex-shrink-0"
                    style={{ backgroundColor: 'var(--muted)' }}
                  >
                    <MapPin size={18} style={{ color: 'var(--primary)' }} />
                  </div>
                  <div className="flex-1 min-w-0">
                    <div className="font-medium mb-1" style={{ color: 'var(--text)' }}>
                      {spot.name}
                    </div>
                    <div className="text-xs mb-2" style={{ color: 'var(--muted-foreground)' }}>
                      {spot.reason} · {spot.floor}
                    </div>
                    <div className="mb-2">
                      <CongestionBadge level={spot.congestion} variant="small" />
                    </div>
                    
                    {/* Text link instead of button */}
                    <button
                      onClick={() => {
                        onSpotClick(spot);
                        onOpenMap();
                      }}
                      className="inline-flex items-center gap-1 text-xs transition-opacity hover:opacity-70"
                      style={{ color: 'var(--primary)' }}
                    >
                      <MapIcon size={12} />
                      <span>マップで見る</span>
                      <ArrowRight size={12} />
                    </button>
                  </div>
                </div>
              </div>
            </div>
          ))}
        </div>
      </section>
    </div>
  );
}
