import { motion } from 'framer-motion';
import { CongestionBadge } from '@/app/components/CongestionBadge';

type Spot = {
  id: string;
  name: string;
  floor: string;
  x: number;
  y: number;
  congestion: 'empty' | 'normal' | 'busy' | 'full';
  category: string;
  isDestination?: boolean;
  isOrigin?: boolean;
};

type MapMarkerProps = {
  spot: Spot;
  isSelected: boolean;
  onClick: () => void;
};

export function MapMarker({ spot, isSelected, onClick }: MapMarkerProps) {
  const congestionColor = {
    empty: 'var(--congestion-empty)',
    normal: 'var(--congestion-normal)',
    busy: 'var(--congestion-busy)',
    full: 'var(--congestion-full)',
  }[spot.congestion];
  
  return (
    <motion.button
      className="absolute -translate-x-1/2 -translate-y-1/2 cursor-pointer group"
      style={{
        left: `${spot.x}%`,
        top: `${spot.y}%`,
      }}
      onClick={onClick}
      initial={{ scale: 0, opacity: 0 }}
      animate={{ 
        scale: isSelected ? 1.2 : 1, 
        opacity: 1,
      }}
      whileTap={{ scale: 0.9 }}
      transition={{ type: 'spring', stiffness: 300, damping: 20 }}
    >
      {/* Outer ring (congestion indicator) */}
      <svg width="40" height="40" viewBox="0 0 40 40" className="absolute inset-0">
        <motion.circle
          cx="20"
          cy="20"
          r="18"
          fill="none"
          stroke={congestionColor}
          strokeWidth={isSelected ? "3" : "2"}
          opacity={isSelected ? "0.8" : "0.4"}
          animate={{
            scale: isSelected ? [1, 1.1, 1] : 1,
          }}
          transition={{
            duration: 2,
            repeat: isSelected ? Infinity : 0,
            ease: "easeInOut",
          }}
        />
      </svg>
      
      {/* Inner marker */}
      <motion.div
        className="relative w-10 h-10 flex items-center justify-center"
        whileHover={{ scale: 1.1 }}
      >
        <div 
          className="w-5 h-5 rounded-full shadow-[--elev-2]"
          style={{
            backgroundColor: spot.isDestination 
              ? 'var(--destructive)' 
              : spot.isOrigin 
              ? 'var(--primary)' 
              : 'var(--surface)',
            border: `2px solid ${spot.isDestination || spot.isOrigin ? 'transparent' : 'var(--primary)'}`,
          }}
        />
      </motion.div>
      
      {/* Tooltip on hover */}
      <div className="absolute top-full left-1/2 -translate-x-1/2 mt-1 opacity-0 group-hover:opacity-100 transition-opacity pointer-events-none whitespace-nowrap z-10">
        <div 
          className="px-2 py-1 rounded text-xs"
          style={{
            backgroundColor: 'var(--surface)',
            color: 'var(--text)',
            boxShadow: 'var(--elev-2)',
          }}
        >
          {spot.name}
        </div>
      </div>
    </motion.button>
  );
}
