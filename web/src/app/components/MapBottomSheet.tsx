import { motion, AnimatePresence } from 'motion/react';
import { X, Navigation, Share2, Bookmark, MapPin, Clock, Star, Heart, Filter, ChevronRight } from 'lucide-react';
import { CongestionBadge } from '@/app/components/CongestionBadge';
import { RouteStepChip } from '@/app/components/RouteStepChip';

type Spot = {
  id: string;
  name: string;
  floor: string;
  congestion: 'empty' | 'normal' | 'busy' | 'full';
  category: string;
  tags?: string[];
  relatedEvents?: number;
  distance?: number;
};

type RouteInfo = {
  distance: number;
  duration: number;
  nextFloor?: string;
  nextLandmark?: string;
  steps: Array<{ floor: string; landmark: string; distance: number }>;
};

type SheetMode = 'idle' | 'search' | 'spot' | 'route' | 'filters';

type MapBottomSheetProps = {
  isOpen: boolean;
  mode: SheetMode;
  spot?: Spot;
  routeInfo?: RouteInfo;
  searchResults?: Spot[];
  onClose: () => void;
  onNavigate?: (spot: Spot) => void;
  onViewEvents?: (spot: Spot) => void;
  onFavorite?: (spot: Spot) => void;
  onSpotSelect?: (spot: Spot) => void;
  onFilterApply?: () => void;
};

const categories = ['全て', '教室', '施設', '食堂', '休憩', '移動'];

export function MapBottomSheet({
  isOpen,
  mode,
  spot,
  routeInfo,
  searchResults = [],
  onClose,
  onNavigate,
  onViewEvents,
  onFavorite,
  onSpotSelect,
  onFilterApply,
}: MapBottomSheetProps) {
  const getSheetHeight = () => {
    switch (mode) {
      case 'idle':
        return '120px';
      case 'search':
      case 'filters':
        return '50vh';
      case 'spot':
        return 'auto';
      case 'route':
        return '60vh';
      default:
        return '120px';
    }
  };
  
  return (
    <AnimatePresence>
      {isOpen && (
        <>
          {/* Backdrop - only for non-idle states */}
          {mode !== 'idle' && (
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              onClick={onClose}
              className="absolute inset-0 bg-black/20 z-30"
            />
          )}
          
          {/* Sheet */}
          <motion.div
            initial={{ y: '100%' }}
            animate={{ y: 0, height: getSheetHeight() }}
            exit={{ y: '100%' }}
            transition={{ type: 'spring', damping: 30, stiffness: 300 }}
            className="absolute bottom-0 left-0 right-0 z-40 rounded-t-3xl overflow-hidden"
            style={{
              backgroundColor: 'var(--surface)',
              boxShadow: 'var(--elev-3)',
              maxHeight: '80vh',
            }}
          >
            {/* Handle */}
            <div className="flex justify-center pt-3 pb-2">
              <div 
                className="w-10 h-1 rounded-full"
                style={{ backgroundColor: 'var(--outline)' }}
              />
            </div>
            
            <div className="px-4 pb-safe overflow-y-auto" style={{ maxHeight: 'calc(80vh - 32px)' }}>
              {/* Idle State */}
              {mode === 'idle' && (
                <div className="text-center py-4">
                  <p className="text-sm" style={{ color: 'var(--muted-foreground)' }}>
                    場所を選択してください
                  </p>
                </div>
              )}
              
              {/* Search State */}
              {mode === 'search' && (
                <div className="pb-4">
                  {/* Category chips */}
                  <div className="flex gap-2 overflow-x-auto pb-3 -mx-4 px-4 mb-3 scrollbar-hide">
                    {categories.map((category) => (
                      <button
                        key={category}
                        className="px-3 py-1.5 rounded-full text-xs font-medium whitespace-nowrap transition-colors"
                        style={{
                          backgroundColor: 'var(--muted)',
                          color: 'var(--text)',
                        }}
                      >
                        {category}
                      </button>
                    ))}
                  </div>
                  
                  {/* Search results */}
                  <div className="space-y-2">
                    {searchResults.map((result) => (
                      <button
                        key={result.id}
                        onClick={() => onSpotSelect?.(result)}
                        className="w-full px-3 py-3 rounded-xl text-left transition-colors hover:bg-[--state-hover]"
                      >
                        <div className="flex items-center gap-3">
                          <div 
                            className="w-10 h-10 rounded-full flex items-center justify-center flex-shrink-0"
                            style={{ backgroundColor: 'var(--muted)' }}
                          >
                            <MapPin size={18} style={{ color: 'var(--primary)' }} />
                          </div>
                          <div className="flex-1 min-w-0">
                            <div className="flex items-center gap-2 mb-1">
                              <span className="font-medium truncate" style={{ color: 'var(--text)' }}>
                                {result.name}
                              </span>
                              <CongestionBadge level={result.congestion} variant="small" />
                            </div>
                            <div className="text-xs" style={{ color: 'var(--muted-foreground)' }}>
                              {result.floor} · {result.category}
                              {result.distance && ` · ${result.distance}m`}
                            </div>
                          </div>
                          <ChevronRight size={18} style={{ color: 'var(--muted-foreground)' }} />
                        </div>
                      </button>
                    ))}
                  </div>
                </div>
              )}
              
              {/* Spot Detail State */}
              {mode === 'spot' && spot && (
                <div className="space-y-4 pb-4">
                  {/* Spot header */}
                  <div className="flex items-start justify-between">
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center gap-2 mb-2">
                        <h3 className="font-medium truncate" style={{ color: 'var(--text)' }}>
                          {spot.name}
                        </h3>
                        <CongestionBadge level={spot.congestion} />
                      </div>
                      <div className="flex items-center gap-2 text-sm mb-3" style={{ color: 'var(--muted-foreground)' }}>
                        <MapPin size={14} />
                        <span>{spot.floor} · {spot.category}</span>
                      </div>
                      
                      {/* Tags */}
                      {spot.tags && (
                        <div className="flex flex-wrap gap-2">
                          {spot.tags.map((tag) => (
                            <span
                              key={tag}
                              className="px-2 py-1 rounded-lg text-xs"
                              style={{
                                backgroundColor: 'var(--muted)',
                                color: 'var(--text)',
                              }}
                            >
                              {tag}
                            </span>
                          ))}
                        </div>
                      )}
                    </div>
                    <button
                      onClick={onClose}
                      className="p-2 rounded-full transition-colors hover:bg-[--state-hover] flex-shrink-0"
                    >
                      <X size={20} style={{ color: 'var(--text)' }} />
                    </button>
                  </div>
                  
                  {/* Actions */}
                  <div className="grid grid-cols-3 gap-2">
                    <button
                      onClick={() => onNavigate?.(spot)}
                      className="flex flex-col items-center gap-2 py-3 rounded-2xl transition-colors"
                      style={{
                        backgroundColor: 'var(--primary)',
                        color: 'var(--primary-foreground)',
                      }}
                    >
                      <Navigation size={20} />
                      <span className="text-xs font-medium">案内</span>
                    </button>
                    
                    {spot.relatedEvents && spot.relatedEvents > 0 && (
                      <button
                        onClick={() => onViewEvents?.(spot)}
                        className="flex flex-col items-center gap-2 py-3 rounded-2xl transition-colors relative"
                        style={{
                          backgroundColor: 'var(--muted)',
                          color: 'var(--text)',
                        }}
                      >
                        <Star size={20} />
                        <span className="text-xs font-medium">イベント</span>
                        {spot.relatedEvents > 0 && (
                          <div 
                            className="absolute top-2 right-2 w-5 h-5 rounded-full flex items-center justify-center text-[10px] font-medium"
                            style={{
                              backgroundColor: 'var(--destructive)',
                              color: 'var(--destructive-foreground)',
                            }}
                          >
                            {spot.relatedEvents}
                          </div>
                        )}
                      </button>
                    )}
                    
                    <button
                      onClick={() => onFavorite?.(spot)}
                      className="flex flex-col items-center gap-2 py-3 rounded-2xl transition-colors"
                      style={{
                        backgroundColor: 'var(--muted)',
                        color: 'var(--text)',
                      }}
                    >
                      <Heart size={20} />
                      <span className="text-xs font-medium">保存</span>
                    </button>
                  </div>
                </div>
              )}
              
              {/* Route State */}
              {mode === 'route' && routeInfo && (
                <div className="space-y-4 pb-4">
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
                        onClick={() => {}}
                      >
                        <Share2 size={18} style={{ color: 'var(--text)' }} />
                      </button>
                      <button
                        onClick={onClose}
                        className="p-2 rounded-full transition-colors hover:bg-[--state-hover]"
                      >
                        <X size={18} style={{ color: 'var(--text)' }} />
                      </button>
                    </div>
                  </div>
                  
                  {/* Next step highlight */}
                  {routeInfo.nextFloor && routeInfo.nextLandmark && (
                    <div 
                      className="p-4 rounded-2xl"
                      style={{ backgroundColor: 'var(--primary-weak)' }}
                    >
                      <div className="text-xs mb-1 font-medium" style={{ color: 'var(--primary)' }}>
                        次の移動
                      </div>
                      <div className="flex items-center gap-2">
                        <Navigation size={16} style={{ color: 'var(--primary)' }} />
                        <span className="font-medium" style={{ color: 'var(--primary)' }}>
                          {routeInfo.nextFloor} へ移動 → {routeInfo.nextLandmark}
                        </span>
                      </div>
                    </div>
                  )}
                  
                  {/* Route steps */}
                  <div className="space-y-1">
                    <div className="text-xs font-medium mb-2" style={{ color: 'var(--muted-foreground)' }}>
                      詳細ルート
                    </div>
                    {routeInfo.steps.map((step, index) => (
                      <div 
                        key={index}
                        className="flex items-start gap-3 py-3 border-l-2 pl-4 ml-3"
                        style={{ 
                          borderColor: index === 0 ? 'var(--primary)' : 'var(--outline)',
                        }}
                      >
                        <div 
                          className="w-6 h-6 rounded-full flex items-center justify-center text-xs font-medium flex-shrink-0 -ml-7"
                          style={{ 
                            backgroundColor: index === 0 ? 'var(--primary)' : 'var(--muted)',
                            color: index === 0 ? 'var(--primary-foreground)' : 'var(--text)',
                          }}
                        >
                          {index + 1}
                        </div>
                        <div className="flex-1 pt-0.5">
                          <div className="text-sm font-medium mb-1" style={{ color: 'var(--text)' }}>
                            {step.landmark}
                          </div>
                          <div className="flex items-center gap-2 text-xs" style={{ color: 'var(--muted-foreground)' }}>
                            <span>{step.floor}</span>
                            <span>·</span>
                            <span className="tabular-nums">{step.distance}m</span>
                          </div>
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              )}
              
              {/* Filters State */}
              {mode === 'filters' && (
                <div className="pb-4">
                  <div className="flex items-center justify-between mb-4">
                    <h3 className="font-medium" style={{ color: 'var(--text)' }}>
                      フィルタ
                    </h3>
                    <button
                      onClick={onClose}
                      className="p-2 rounded-full transition-colors hover:bg-[--state-hover]"
                    >
                      <X size={20} style={{ color: 'var(--text)' }} />
                    </button>
                  </div>
                  
                  {/* Filter sections */}
                  <div className="space-y-4">
                    {/* Category filter */}
                    <div>
                      <div className="text-sm font-medium mb-2" style={{ color: 'var(--text)' }}>
                        カテゴリ
                      </div>
                      <div className="flex flex-wrap gap-2">
                        {categories.map((category) => (
                          <button
                            key={category}
                            className="px-3 py-1.5 rounded-full text-xs font-medium transition-colors"
                            style={{
                              backgroundColor: 'var(--muted)',
                              color: 'var(--text)',
                            }}
                          >
                            {category}
                          </button>
                        ))}
                      </div>
                    </div>
                    
                    {/* Crowd filter */}
                    <div>
                      <div className="text-sm font-medium mb-2" style={{ color: 'var(--text)' }}>
                        混雑状況
                      </div>
                      <div className="flex flex-wrap gap-2">
                        <CongestionBadge level="empty" />
                        <CongestionBadge level="normal" />
                        <CongestionBadge level="busy" />
                        <CongestionBadge level="full" />
                      </div>
                    </div>
                    
                    {/* Other filters */}
                    <div className="space-y-2">
                      <label className="flex items-center gap-3 p-3 rounded-xl transition-colors hover:bg-[--state-hover]">
                        <input type="checkbox" className="w-5 h-5" />
                        <span className="text-sm" style={{ color: 'var(--text)' }}>営業中のみ表示</span>
                      </label>
                      <label className="flex items-center gap-3 p-3 rounded-xl transition-colors hover:bg-[--state-hover]">
                        <input type="checkbox" className="w-5 h-5" />
                        <span className="text-sm" style={{ color: 'var(--text)' }}>バリアフリー対応</span>
                      </label>
                    </div>
                  </div>
                  
                  {/* Apply button */}
                  <button
                    onClick={onFilterApply}
                    className="w-full mt-4 py-3 rounded-2xl font-medium transition-colors"
                    style={{
                      backgroundColor: 'var(--primary)',
                      color: 'var(--primary-foreground)',
                    }}
                  >
                    フィルタを適用
                  </button>
                </div>
              )}
            </div>
          </motion.div>
        </>
      )}
    </AnimatePresence>
  );
}
