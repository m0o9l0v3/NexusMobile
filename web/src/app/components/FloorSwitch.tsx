import { motion } from 'motion/react';

type FloorSwitchProps = {
  floors: string[];
  currentFloor: string;
  onFloorChange: (floor: string) => void;
};

export function FloorSwitch({ floors, currentFloor, onFloorChange }: FloorSwitchProps) {
  return (
    <div 
      className="inline-flex rounded-full p-1 gap-1"
      style={{ 
        backgroundColor: 'var(--surface)',
        boxShadow: 'var(--elev-2)',
      }}
    >
      {floors.map((floor) => {
        const isActive = floor === currentFloor;
        
        return (
          <button
            key={floor}
            onClick={() => onFloorChange(floor)}
            className="relative px-3 py-1.5 rounded-full text-xs font-medium transition-colors min-w-[48px]"
            style={{
              color: isActive ? 'var(--primary)' : 'var(--muted-foreground)',
            }}
          >
            {isActive && (
              <motion.div
                layoutId="floor-active-bg"
                className="absolute inset-0 rounded-full"
                style={{ backgroundColor: 'var(--primary-weak)' }}
                transition={{ type: 'spring', stiffness: 300, damping: 30 }}
              />
            )}
            <span className="relative z-10">{floor}</span>
          </button>
        );
      })}
    </div>
  );
}
