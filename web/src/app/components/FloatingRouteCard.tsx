import { motion, AnimatePresence } from 'motion/react';
import { ArrowDownUp, Search } from 'lucide-react';
import { SuggestListItem } from '@/app/components/SuggestListItem';

type Spot = {
  id: string;
  name: string;
  floor: string;
  congestion: 'empty' | 'normal' | 'busy' | 'full';
  category: string;
  distance?: number;
};

type FloatingRouteCardProps = {
  isExpanded: boolean;
  fromSpot?: Spot;
  toSpot?: Spot;
  suggestions?: Spot[];
  activeInput?: 'from' | 'to' | null;
  onExpand: () => void;
  onSwap: () => void;
  onInputChange: (type: 'from' | 'to', value: string) => void;
  onSuggestionSelect: (type: 'from' | 'to', spot: Spot) => void;
  onSearch: () => void;
};

const commonDestinations = [
  { label: '受付', id: 'reception' },
  { label: '入口', id: 'entrance' },
  { label: '階段A', id: 'stairs-a' },
];

export function FloatingRouteCard({
  isExpanded,
  fromSpot,
  toSpot,
  suggestions = [],
  activeInput,
  onExpand,
  onSwap,
  onInputChange,
  onSuggestionSelect,
  onSearch,
}: FloatingRouteCardProps) {
  return (
    <motion.div
      className="absolute top-4 left-4 right-4 z-20"
      initial={false}
      animate={{
        boxShadow: isExpanded ? 'var(--elev-3)' : 'var(--elev-2)',
      }}
    >
      <motion.div
        className="rounded-3xl overflow-hidden"
        style={{
          backgroundColor: 'var(--surface)',
        }}
        layout
      >
        <div className="p-4">
          <div className="flex items-center gap-3">
            {/* From/To Inputs */}
            <div className="flex-1 flex flex-col gap-2">
              {/* From */}
              <button
                onClick={() => {
                  onExpand();
                  onInputChange('from', '');
                }}
                className="flex items-center gap-2 px-3 py-2 rounded-xl text-left transition-colors"
                style={{
                  backgroundColor: activeInput === 'from' ? 'var(--state-hover)' : 'var(--muted)',
                }}
              >
                <div 
                  className="w-2 h-2 rounded-full flex-shrink-0"
                  style={{ backgroundColor: 'var(--primary)' }}
                />
                <span className="text-sm flex-1 truncate" style={{ color: 'var(--text)' }}>
                  {fromSpot?.name || '出発地を選択'}
                </span>
              </button>
              
              {/* To */}
              <button
                onClick={() => {
                  onExpand();
                  onInputChange('to', '');
                }}
                className="flex items-center gap-2 px-3 py-2 rounded-xl text-left transition-colors"
                style={{
                  backgroundColor: activeInput === 'to' ? 'var(--state-hover)' : 'var(--muted)',
                }}
              >
                <div 
                  className="w-2 h-2 rounded-full flex-shrink-0"
                  style={{ backgroundColor: 'var(--destructive)' }}
                />
                <span className="text-sm flex-1 truncate" style={{ color: 'var(--text)' }}>
                  {toSpot?.name || '目的地を選択'}
                </span>
              </button>
            </div>
            
            {/* Swap button */}
            <motion.button
              onClick={onSwap}
              className="p-2 rounded-full transition-colors"
              style={{ backgroundColor: 'var(--muted)' }}
              whileTap={{ scale: 0.9, backgroundColor: 'var(--state-pressed)' }}
              disabled={!fromSpot || !toSpot}
            >
              <ArrowDownUp size={20} style={{ color: 'var(--text)' }} />
            </motion.button>
            
            {/* Search/GO button */}
            <motion.button
              onClick={onSearch}
              className="px-4 py-2 rounded-full transition-colors flex items-center gap-2"
              style={{ 
                backgroundColor: fromSpot && toSpot ? 'var(--primary)' : 'var(--muted)',
                color: fromSpot && toSpot ? 'var(--primary-foreground)' : 'var(--muted-foreground)',
              }}
              whileTap={{ scale: 0.95 }}
              disabled={!fromSpot || !toSpot}
            >
              <Search size={18} />
              <span className="text-sm font-medium">GO</span>
            </motion.button>
          </div>
          
          {/* Common destinations chips */}
          <AnimatePresence>
            {isExpanded && !activeInput && (
              <motion.div
                initial={{ opacity: 0, height: 0 }}
                animate={{ opacity: 1, height: 'auto' }}
                exit={{ opacity: 0, height: 0 }}
                className="mt-3 flex flex-wrap gap-2 overflow-hidden"
              >
                {commonDestinations.map((dest) => (
                  <button
                    key={dest.id}
                    className="px-3 py-1.5 rounded-full text-xs transition-colors"
                    style={{
                      backgroundColor: 'var(--muted)',
                      color: 'var(--text)',
                    }}
                    onClick={() => {
                      // Handle common destination selection
                    }}
                  >
                    {dest.label}
                  </button>
                ))}
              </motion.div>
            )}
          </AnimatePresence>
        </div>
        
        {/* Suggestions list */}
        <AnimatePresence>
          {isExpanded && activeInput && suggestions.length > 0 && (
            <motion.div
              initial={{ opacity: 0, height: 0 }}
              animate={{ opacity: 1, height: 'auto' }}
              exit={{ opacity: 0, height: 0 }}
              className="border-t max-h-[280px] overflow-y-auto"
              style={{ borderColor: 'var(--outline)' }}
            >
              {suggestions.map((spot) => (
                <SuggestListItem
                  key={spot.id}
                  spot={spot}
                  onClick={() => onSuggestionSelect(activeInput, spot)}
                />
              ))}
            </motion.div>
          )}
        </AnimatePresence>
      </motion.div>
    </motion.div>
  );
}
