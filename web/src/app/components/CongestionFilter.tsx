import { motion, AnimatePresence } from 'motion/react';
import { X } from 'lucide-react';
import { CongestionBadge } from '@/app/components/CongestionBadge';

type CongestionLevel = 'empty' | 'normal' | 'busy' | 'full';

type CongestionFilterProps = {
  isOpen: boolean;
  selectedLevels: CongestionLevel[];
  onToggle: () => void;
  onLevelToggle: (level: CongestionLevel) => void;
  onClear: () => void;
};

const levels: CongestionLevel[] = ['empty', 'normal', 'busy', 'full'];

const presets = [
  { id: 'empty-only', label: '空いているのみ', levels: ['empty'] as CongestionLevel[] },
  { id: 'no-full', label: '満は非表示', levels: ['empty', 'normal', 'busy'] as CongestionLevel[] },
];

export function CongestionFilter({
  isOpen,
  selectedLevels,
  onToggle,
  onLevelToggle,
  onClear,
}: CongestionFilterProps) {
  const hasFilters = selectedLevels.length > 0 && selectedLevels.length < 4;
  
  return (
    <>
      {/* Filter panel */}
      <AnimatePresence>
        {isOpen && (
          <motion.div
            initial={{ opacity: 0, y: -10 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -10 }}
            className="absolute right-0 mt-2 p-3 rounded-2xl"
            style={{
              backgroundColor: 'var(--surface)',
              boxShadow: 'var(--elev-2)',
              width: '240px',
              top: '48px',
            }}
          >
            <div>
              {/* Header */}
              <div className="flex items-center justify-between mb-3">
                <h4 className="text-xs font-medium" style={{ color: 'var(--text)' }}>
                  混雑フィルタ
                </h4>
                {hasFilters && (
                  <button
                    onClick={onClear}
                    className="text-xs transition-colors"
                    style={{ color: 'var(--primary)' }}
                  >
                    クリア
                  </button>
                )}
              </div>
              
              {/* Level toggles */}
              <div className="space-y-1.5 mb-3">
                {levels.map((level) => {
                  const isSelected = selectedLevels.includes(level);
                  
                  return (
                    <button
                      key={level}
                      onClick={() => onLevelToggle(level)}
                      className="w-full flex items-center justify-between p-2 rounded-lg text-xs transition-colors"
                      style={{
                        backgroundColor: isSelected ? 'var(--primary-weak)' : 'transparent',
                      }}
                    >
                      <CongestionBadge level={level} />
                      <div 
                        className="w-4 h-4 rounded border-2 flex items-center justify-center transition-colors"
                        style={{
                          borderColor: isSelected ? 'var(--primary)' : 'var(--outline)',
                          backgroundColor: isSelected ? 'var(--primary)' : 'transparent',
                        }}
                      >
                        {isSelected && (
                          <svg width="12" height="12" viewBox="0 0 12 12" fill="none">
                            <path
                              d="M2 6L5 9L10 3"
                              stroke="white"
                              strokeWidth="2"
                              strokeLinecap="round"
                              strokeLinejoin="round"
                            />
                          </svg>
                        )}
                      </div>
                    </button>
                  );
                })}
              </div>
              
              {/* Presets */}
              <div className="pt-2 border-t" style={{ borderColor: 'var(--outline)' }}>
                <div className="text-[10px] mb-1.5" style={{ color: 'var(--muted-foreground)' }}>
                  プリセット
                </div>
                <div className="space-y-1.5">
                  {presets.map((preset) => (
                    <button
                      key={preset.id}
                      onClick={() => {
                        onClear();
                        preset.levels.forEach(level => onLevelToggle(level));
                      }}
                      className="w-full px-3 py-1.5 rounded-lg text-xs text-left transition-colors"
                      style={{
                        backgroundColor: 'var(--muted)',
                        color: 'var(--text)',
                      }}
                    >
                      {preset.label}
                    </button>
                  ))}
                </div>
              </div>
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </>
  );
}
