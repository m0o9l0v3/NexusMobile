import { motion } from 'motion/react';
import { MapPin } from 'lucide-react';

type MapHeroCardProps = {
  onOpenMap: () => void;
  currentLocation?: string;
  currentFloor?: string;
};

export function MapHeroCard({ onOpenMap, currentLocation = '受付付近', currentFloor = '1F' }: MapHeroCardProps) {
  return (
    <motion.button
      onClick={onOpenMap}
      className="w-full rounded-3xl p-6 text-left overflow-hidden relative"
      style={{
        backgroundColor: 'var(--surface)',
        boxShadow: 'var(--elev-2)',
      }}
      whileTap={{ scale: 0.98 }}
    >
      {/* Gradient background overlay - very subtle */}
      <div 
        className="absolute inset-0 opacity-20"
        style={{
          background: 'linear-gradient(135deg, rgba(33, 150, 243, 0.06) 0%, rgba(144, 202, 249, 0.08) 100%)',
        }}
      />
      
      {/* Abstract map visual - much quieter */}
      <div className="absolute right-4 top-4 opacity-5">
        <svg width="120" height="120" viewBox="0 0 120 120" fill="none">
          {/* Grid lines */}
          <line x1="20" y1="0" x2="20" y2="120" stroke="currentColor" strokeWidth="1" opacity="0.3" />
          <line x1="50" y1="0" x2="50" y2="120" stroke="currentColor" strokeWidth="1" opacity="0.3" />
          <line x1="80" y1="0" x2="80" y2="120" stroke="currentColor" strokeWidth="1" opacity="0.3" />
          <line x1="0" y1="30" x2="120" y2="30" stroke="currentColor" strokeWidth="1" opacity="0.3" />
          <line x1="0" y1="60" x2="120" y2="60" stroke="currentColor" strokeWidth="1" opacity="0.3" />
          <line x1="0" y1="90" x2="120" y2="90" stroke="currentColor" strokeWidth="1" opacity="0.3" />
          
          {/* Abstract buildings */}
          <rect x="15" y="25" width="15" height="25" fill="currentColor" opacity="0.4" rx="2" />
          <rect x="45" y="35" width="20" height="35" fill="currentColor" opacity="0.5" rx="2" />
          <rect x="75" y="20" width="18" height="30" fill="currentColor" opacity="0.4" rx="2" />
          
          {/* Route line */}
          <path 
            d="M30 80 Q50 70, 70 75 T100 65" 
            stroke="currentColor" 
            strokeWidth="2" 
            fill="none" 
            strokeDasharray="4 4"
            opacity="0.6"
          />
          
          {/* Pin markers */}
          <circle cx="30" cy="80" r="4" fill="currentColor" opacity="0.7" />
          <circle cx="100" cy="65" r="4" fill="currentColor" opacity="0.7" />
        </svg>
      </div>
      
      {/* Content */}
      <div className="relative z-10">
        <div className="text-xs mb-3" style={{ color: 'var(--muted-foreground)' }}>
          {currentLocation} · {currentFloor}
        </div>
        
        <h2 className="text-xl font-bold mb-2" style={{ color: 'var(--text)' }}>
          キャンパスマップ
        </h2>
        
        <p className="text-sm mb-4" style={{ color: 'var(--muted-foreground)' }}>
          探索して、目的地へ向かいましょう
        </p>
        
        <div 
          className="inline-flex px-4 py-2 rounded-full font-medium text-sm"
          style={{
            backgroundColor: 'var(--primary)',
            color: 'var(--primary-foreground)',
          }}
        >
          マップを開く
        </div>
      </div>
    </motion.button>
  );
}
