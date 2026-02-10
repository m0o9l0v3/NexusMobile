import { motion, AnimatePresence } from 'motion/react';
import { X, Navigation, Share2, Bookmark, MapPin, Clock } from 'lucide-react';
import { CongestionBadge } from '@/app/components/CongestionBadge';
import { RouteStepChip } from '@/app/components/RouteStepChip';

type Spot = {
  id: string;
  name: string;
  floor: string;
  congestion: 'empty' | 'normal' | 'busy' | 'full';
  category: string;
};

type RouteInfo = {
  distance: number;
  duration: number;
  nextFloor?: string;
  nextLandmark?: string;
  steps: Array<{ floor: string; landmark: string }>;
};

type BottomSheetProps = {
  isOpen: boolean;
  mode: 'spot' | 'route' | null;
  spot?: Spot;
  routeInfo?: RouteInfo;
  onClose: () => void;
  onSetDestination?: (spot: Spot) => void;
  onSetOrigin?: (spot: Spot) => void;
  onClearRoute?: () => void;
};

export function BottomSheet({
  isOpen,
  mode,
  spot,
  routeInfo,
  onClose,
  onSetDestination,
  onSetOrigin,
  onClearRoute,
}: BottomSheetProps) {
  return (
    <AnimatePresence>
      {isOpen && (
        <>
          {/* Backdrop */}
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            onClick={onClose}
            className="absolute inset-0 bg-black/20 z-30"
          />
          
          {/* Sheet */}
          <motion.div
            initial={{ y: '100%' }}
            animate={{ y: 0 }}
            exit={{ y: '100%' }}
            transition={{ type: 'spring', damping: 30, stiffness: 300 }}
            className="absolute bottom-0 left-0 right-0 z-40 rounded-t-3xl overflow-hidden"
            style={{
              backgroundColor: 'var(--surface)',
              boxShadow: 'var(--elev-3)',
              maxHeight: '70vh',
            }}
          >
            {/* Handle */}
            <div className="flex justify-center pt-3 pb-2">
              <div 
                className="w-10 h-1 rounded-full"
                style={{ backgroundColor: 'var(--outline)' }}
              />
            </div>
            
            <div className="px-4 pb-4 overflow-y-auto max-h-[calc(70vh-32px)]">
              {mode === 'spot' && spot && (
                <div className="space-y-4">
                  {/* Spot header */}
                  <div className="flex items-start justify-between">
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center gap-2 mb-1">
                        <h3 className="font-medium truncate" style={{ color: 'var(--text)' }}>
                          {spot.name}
                        </h3>
                        <CongestionBadge level={spot.congestion} />
                      </div>
                      <div className="flex items-center gap-2 text-sm" style={{ color: 'var(--muted-foreground)' }}>
                        <MapPin size={14} />
                        <span>{spot.floor} · {spot.category}</span>
                      </div>
                    </div>
                    <button
                      onClick={onClose}
                      className="p-2 rounded-full transition-colors hover:bg-[--state-hover]"
                    >
                      <X size={20} style={{ color: 'var(--text)' }} />
                    </button>
                  </div>
                  
                  {/* Actions */}
                  <div className="flex gap-2">
                    <button
                      onClick={() => {
                        onSetDestination?.(spot);
                        onClose();
                      }}
                      className="flex-1 py-3 rounded-2xl font-medium transition-colors"
                      style={{
                        backgroundColor: 'var(--primary)',
                        color: 'var(--primary-foreground)',
                      }}
                    >
                      目的地に設定
                    </button>
                    <button
                      onClick={() => {
                        onSetOrigin?.(spot);
                        onClose();
                      }}
                      className="flex-1 py-3 rounded-2xl font-medium transition-colors"
                      style={{
                        backgroundColor: 'var(--muted)',
                        color: 'var(--text)',
                      }}
                    >
                      出発地に設定
                    </button>
                  </div>
                </div>
              )}
              
              {mode === 'route' && routeInfo && (
                <div className="space-y-4">
                  {/* Route summary */}
                  <div className="flex items-start justify-between">
                    <div className="flex-1">
                      <h3 className="font-medium mb-3" style={{ color: 'var(--text)' }}>
                        ルート案内
                      </h3>
                      <div className="flex gap-4">
                        <div className="flex items-center gap-2">
                          <Navigation size={16} style={{ color: 'var(--primary)' }} />
                          <span className="text-sm tabular-nums" style={{ color: 'var(--text)' }}>
                            {routeInfo.distance}m
                          </span>
                        </div>
                        <div className="flex items-center gap-2">
                          <Clock size={16} style={{ color: 'var(--primary)' }} />
                          <span className="text-sm tabular-nums" style={{ color: 'var(--text)' }}>
                            約{routeInfo.duration}分
                          </span>
                        </div>
                      </div>
                    </div>
                    
                    <div className="flex gap-2">
                      <button
                        className="p-2 rounded-full transition-colors hover:bg-[--state-hover]"
                        onClick={() => {
                          // Share functionality
                        }}
                      >
                        <Share2 size={18} style={{ color: 'var(--text)' }} />
                      </button>
                      <button
                        className="p-2 rounded-full transition-colors hover:bg-[--state-hover]"
                        onClick={() => {
                          // Save functionality
                        }}
                      >
                        <Bookmark size={18} style={{ color: 'var(--text)' }} />
                      </button>
                    </div>
                  </div>
                  
                  {/* Next step */}
                  {routeInfo.nextFloor && routeInfo.nextLandmark && (
                    <div 
                      className="p-3 rounded-2xl"
                      style={{ backgroundColor: 'var(--muted)' }}
                    >
                      <div className="text-xs mb-1" style={{ color: 'var(--muted-foreground)' }}>
                        次の移動
                      </div>
                      <div className="flex gap-2">
                        <RouteStepChip label={`${routeInfo.nextFloor}`} />
                        <RouteStepChip label={routeInfo.nextLandmark} />
                      </div>
                    </div>
                  )}
                  
                  {/* Route steps */}
                  <div className="space-y-2">
                    <div className="text-xs font-medium" style={{ color: 'var(--muted-foreground)' }}>
                      ルート詳細
                    </div>
                    {routeInfo.steps.map((step, index) => (
                      <div 
                        key={index}
                        className="flex items-center gap-3 py-2"
                      >
                        <div 
                          className="w-6 h-6 rounded-full flex items-center justify-center text-xs font-medium flex-shrink-0"
                          style={{ 
                            backgroundColor: 'var(--primary-weak)',
                            color: 'var(--primary)',
                          }}
                        >
                          {index + 1}
                        </div>
                        <div className="flex-1">
                          <div className="text-sm" style={{ color: 'var(--text)' }}>
                            {step.landmark}
                          </div>
                          <div className="text-xs" style={{ color: 'var(--muted-foreground)' }}>
                            {step.floor}
                          </div>
                        </div>
                      </div>
                    ))}
                  </div>
                  
                  {/* Actions */}
                  <div className="flex gap-2 pt-2">
                    <button
                      onClick={onClearRoute}
                      className="flex-1 py-3 rounded-2xl font-medium transition-colors"
                      style={{
                        backgroundColor: 'var(--muted)',
                        color: 'var(--text)',
                      }}
                    >
                      ルート解除
                    </button>
                    <button
                      onClick={onClose}
                      className="flex-1 py-3 rounded-2xl font-medium transition-colors"
                      style={{
                        backgroundColor: 'var(--primary)',
                        color: 'var(--primary-foreground)',
                      }}
                    >
                      閉じる
                    </button>
                  </div>
                </div>
              )}
            </div>
          </motion.div>
        </>
      )}
    </AnimatePresence>
  );
}
