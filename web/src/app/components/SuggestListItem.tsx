import { MapPin } from 'lucide-react';
import { CongestionBadge } from '@/app/components/CongestionBadge';

type Spot = {
  id: string;
  name: string;
  floor: string;
  congestion: 'empty' | 'normal' | 'busy' | 'full';
  category: string;
  distance?: number;
};

type SuggestListItemProps = {
  spot: Spot;
  onClick: () => void;
};

export function SuggestListItem({ spot, onClick }: SuggestListItemProps) {
  return (
    <button
      onClick={onClick}
      className="w-full px-4 py-3 flex items-center gap-3 transition-colors hover:bg-[--state-hover] active:bg-[--state-pressed]"
    >
      <div 
        className="w-10 h-10 rounded-full flex items-center justify-center flex-shrink-0"
        style={{ backgroundColor: 'var(--muted)' }}
      >
        <MapPin size={18} style={{ color: 'var(--primary)' }} />
      </div>
      
      <div className="flex-1 text-left min-w-0">
        <div className="flex items-center gap-2">
          <span className="font-medium truncate" style={{ color: 'var(--text)' }}>
            {spot.name}
          </span>
          <CongestionBadge level={spot.congestion} variant="small" />
        </div>
        <div className="flex items-center gap-2 mt-0.5">
          <span className="text-xs" style={{ color: 'var(--muted-foreground)' }}>
            {spot.floor} · {spot.category}
          </span>
          {spot.distance !== undefined && (
            <>
              <span className="text-xs" style={{ color: 'var(--muted-foreground)' }}>·</span>
              <span className="text-xs tabular-nums" style={{ color: 'var(--muted-foreground)' }}>
                {spot.distance}m
              </span>
            </>
          )}
        </div>
      </div>
    </button>
  );
}
