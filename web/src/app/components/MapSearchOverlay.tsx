import { useState, useEffect, useRef } from 'react';
import { motion, AnimatePresence } from 'motion/react';
import { ArrowUpDown, Mic, Plus, X, Navigation } from 'lucide-react';

type MapSearchOverlayProps = {
  isOpen: boolean;
  onClose: () => void;
  onSearch?: (origin: string, destination: string, waypoints: string[]) => void;
};

export function MapSearchOverlay({ isOpen, onClose, onSearch }: MapSearchOverlayProps) {
  const [origin, setOrigin] = useState('現在地');
  const [destination, setDestination] = useState('');
  const [waypoints, setWaypoints] = useState<string[]>([]);
  
  const originInputRef = useRef<HTMLInputElement>(null);
  const destinationInputRef = useRef<HTMLInputElement>(null);
  
  // Auto-focus origin input when overlay opens
  useEffect(() => {
    if (isOpen && originInputRef.current) {
      // Small delay to ensure animation completes
      setTimeout(() => {
        originInputRef.current?.focus();
        originInputRef.current?.select();
      }, 300);
    }
  }, [isOpen]);
  
  const handleSwap = () => {
    const temp = origin;
    setOrigin(destination);
    setDestination(temp);
  };
  
  const handleAddWaypoint = () => {
    setWaypoints([...waypoints, '']);
  };
  
  const handleRemoveWaypoint = (index: number) => {
    setWaypoints(waypoints.filter((_, i) => i !== index));
  };
  
  const handleWaypointChange = (index: number, value: string) => {
    const newWaypoints = [...waypoints];
    newWaypoints[index] = value;
    setWaypoints(newWaypoints);
  };
  
  const handleSubmitSearch = () => {
    if (onSearch) {
      onSearch(origin, destination, waypoints);
    }
  };
  
  return (
    <AnimatePresence>
      {isOpen && (
        <>
          {/* Backdrop */}
          <motion.div
            className="fixed inset-0 z-40"
            style={{ backgroundColor: 'rgba(0, 0, 0, 0.2)' }}
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            onClick={onClose}
          />
          
          {/* Search Overlay */}
          <motion.div
            className="fixed left-0 right-0 z-50 overflow-y-auto"
            style={{
              top: 0,
              backgroundColor: 'var(--background)',
              maxHeight: '85vh',
            }}
            initial={{ y: '-100%' }}
            animate={{ y: 0 }}
            exit={{ y: '-100%' }}
            transition={{
              type: 'spring',
              stiffness: 300,
              damping: 30,
            }}
          >
            <div className="safe-area-inset-top">
              {/* Header */}
              <div 
                className="flex items-center justify-between px-4 py-2.5 border-b"
                style={{ borderColor: 'var(--outline)' }}
              >
                <button
                  onClick={onClose}
                  className="w-9 h-9 rounded-full flex items-center justify-center transition-colors"
                  style={{ 
                    backgroundColor: 'transparent',
                    color: 'var(--text)',
                  }}
                >
                  <X size={22} />
                </button>
                
                <h2 className="text-sm font-medium" style={{ color: 'var(--text)' }}>
                  経路を検索
                </h2>
                
                <div className="w-9" />
              </div>
              
              {/* Search Inputs */}
              <div className="px-4 py-3">
                <div className="relative">
                  {/* Origin Input */}
                  <div className="flex items-center gap-2 mb-2">
                    <div className="flex-shrink-0 flex flex-col items-center gap-0.5">
                      <div 
                        className="w-3 h-3 rounded-full"
                        style={{ backgroundColor: 'var(--primary)' }}
                      />
                      <div 
                        className="w-0.5 flex-1"
                        style={{ 
                          backgroundColor: 'var(--outline)',
                          minHeight: '20px',
                        }}
                      />
                    </div>
                    
                    <div className="flex-1">
                      <div className="flex items-center gap-2 mb-1">
                        <div 
                          className="px-2 py-0.5 rounded-full text-[10px] font-medium"
                          style={{
                            backgroundColor: 'var(--primary-weak)',
                            color: 'var(--primary)',
                          }}
                        >
                          出発
                        </div>
                      </div>
                      
                      <div className="flex items-center gap-2">
                        <input
                          ref={originInputRef}
                          type="text"
                          value={origin}
                          onChange={(e) => setOrigin(e.target.value)}
                          placeholder="出発地を入力"
                          className="flex-1 px-3 py-2.5 rounded-2xl text-sm outline-none transition-colors"
                          style={{
                            backgroundColor: 'var(--muted)',
                            color: 'var(--text)',
                            border: '2px solid transparent',
                          }}
                          onFocus={(e) => {
                            e.target.style.borderColor = 'var(--primary)';
                            e.target.style.backgroundColor = 'var(--surface)';
                          }}
                          onBlur={(e) => {
                            e.target.style.borderColor = 'transparent';
                            e.target.style.backgroundColor = 'var(--muted)';
                          }}
                        />
                        
                        <button
                          className="w-9 h-9 rounded-full flex items-center justify-center flex-shrink-0"
                          style={{
                            backgroundColor: 'var(--muted)',
                            color: 'var(--muted-foreground)',
                          }}
                          onClick={() => setOrigin('現在地')}
                          title="現在地を使用"
                        >
                          <Navigation size={16} />
                        </button>
                      </div>
                    </div>
                  </div>
                  
                  {/* Waypoints */}
                  {waypoints.map((waypoint, index) => (
                    <div key={index} className="flex items-center gap-2 mb-2">
                      <div className="flex-shrink-0 flex flex-col items-center gap-0.5">
                        <div 
                          className="w-2 h-2 rounded-full"
                          style={{ backgroundColor: 'var(--muted-foreground)' }}
                        />
                        <div 
                          className="w-0.5 flex-1"
                          style={{ 
                            backgroundColor: 'var(--outline)',
                            minHeight: '20px',
                          }}
                        />
                      </div>
                      
                      <div className="flex-1">
                        <div className="flex items-center gap-2 mb-1">
                          <div 
                            className="px-2 py-0.5 rounded-full text-[10px] font-medium"
                            style={{
                              backgroundColor: 'var(--muted)',
                              color: 'var(--muted-foreground)',
                            }}
                          >
                            経由
                          </div>
                        </div>
                        
                        <div className="flex items-center gap-2">
                          <input
                            type="text"
                            value={waypoint}
                            onChange={(e) => handleWaypointChange(index, e.target.value)}
                            placeholder="経由地を入力"
                            className="flex-1 px-3 py-2.5 rounded-2xl text-sm outline-none transition-colors"
                            style={{
                              backgroundColor: 'var(--muted)',
                              color: 'var(--text)',
                              border: '2px solid transparent',
                            }}
                            onFocus={(e) => {
                              e.target.style.borderColor = 'var(--primary)';
                              e.target.style.backgroundColor = 'var(--surface)';
                            }}
                            onBlur={(e) => {
                              e.target.style.borderColor = 'transparent';
                              e.target.style.backgroundColor = 'var(--muted)';
                            }}
                          />
                          
                          <button
                            className="w-9 h-9 rounded-full flex items-center justify-center flex-shrink-0"
                            style={{
                              backgroundColor: 'var(--muted)',
                              color: 'var(--muted-foreground)',
                            }}
                            onClick={() => handleRemoveWaypoint(index)}
                          >
                            <X size={16} />
                          </button>
                        </div>
                      </div>
                    </div>
                  ))}
                  
                  {/* Destination Input */}
                  <div className="flex items-center gap-2 mb-3">
                    <div className="flex-shrink-0 flex flex-col items-center">
                      <div 
                        className="w-3 h-3 rounded-sm"
                        style={{ 
                          backgroundColor: 'var(--primary)',
                          transform: 'rotate(45deg)',
                        }}
                      />
                    </div>
                    
                    <div className="flex-1">
                      <div className="flex items-center gap-2 mb-1">
                        <div 
                          className="px-2 py-0.5 rounded-full text-[10px] font-medium"
                          style={{
                            backgroundColor: 'var(--primary-weak)',
                            color: 'var(--primary)',
                          }}
                        >
                          到着
                        </div>
                      </div>
                      
                      <div className="flex items-center gap-2">
                        <input
                          ref={destinationInputRef}
                          type="text"
                          value={destination}
                          onChange={(e) => setDestination(e.target.value)}
                          placeholder="教室・施設を検索"
                          className="flex-1 px-3 py-2.5 rounded-2xl text-sm outline-none transition-colors"
                          style={{
                            backgroundColor: 'var(--muted)',
                            color: 'var(--text)',
                            border: '2px solid transparent',
                          }}
                          onFocus={(e) => {
                            e.target.style.borderColor = 'var(--primary)';
                            e.target.style.backgroundColor = 'var(--surface)';
                          }}
                          onBlur={(e) => {
                            e.target.style.borderColor = 'transparent';
                            e.target.style.backgroundColor = 'var(--muted)';
                          }}
                        />
                        
                        <button
                          className="w-9 h-9 rounded-full flex items-center justify-center flex-shrink-0"
                          style={{
                            backgroundColor: 'var(--muted)',
                            color: 'var(--muted-foreground)',
                          }}
                          title="音声入力"
                        >
                          <Mic size={16} />
                        </button>
                      </div>
                    </div>
                  </div>
                  
                  {/* Control Buttons */}
                  <div className="flex items-center gap-2 pl-5 mb-4">
                    <button
                      onClick={handleAddWaypoint}
                      className="flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs transition-colors"
                      style={{
                        backgroundColor: 'transparent',
                        color: 'var(--primary)',
                        border: '1px solid var(--outline)',
                      }}
                    >
                      <Plus size={14} />
                      <span>経由地を追加</span>
                    </button>
                    
                    <button
                      onClick={handleSwap}
                      className="w-9 h-9 rounded-full flex items-center justify-center transition-colors"
                      style={{
                        backgroundColor: 'transparent',
                        color: 'var(--muted-foreground)',
                        border: '1px solid var(--outline)',
                      }}
                      title="入替"
                    >
                      <ArrowUpDown size={16} />
                    </button>
                  </div>
                  
                  {/* Search Button */}
                  <button
                    onClick={handleSubmitSearch}
                    className="w-full py-3.5 rounded-3xl text-base font-medium transition-all"
                    style={{
                      backgroundColor: 'var(--primary)',
                      color: 'var(--primary-foreground)',
                    }}
                  >
                    検索
                  </button>
                </div>
              </div>
              
              {/* Keyboard spacer - simulates keyboard presence */}
              <div style={{ height: '30vh' }} />
            </div>
          </motion.div>
        </>
      )}
    </AnimatePresence>
  );
}
