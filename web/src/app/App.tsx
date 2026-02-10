import { useState } from 'react';
import { motion } from 'motion/react';
import { Sparkles } from 'lucide-react';
import { HomeScreen } from '@/app/components/HomeScreen';
import { MapScreen } from '@/app/components/MapScreen';
import { EventsScreen } from '@/app/components/EventsScreen';
import { BottomNav } from '@/app/components/BottomNav';
import { MapBottomSheet } from '@/app/components/MapBottomSheet';
import { SupportSheet } from '@/app/components/SupportSheet';

type CongestionLevel = 'empty' | 'normal' | 'busy' | 'full';

type Spot = {
  id: string;
  name: string;
  floor: string;
  x: number;
  y: number;
  congestion: CongestionLevel;
  category: string;
  distance?: number;
  isDestination?: boolean;
  isOrigin?: boolean;
  tags?: string[];
  relatedEvents?: number;
};

type Event = {
  id: string;
  title: string;
  time: string;
  endTime?: string;
  location: string;
  floor?: string;
  department: string;
  category?: string;
  description?: string;
};

type RouteInfo = {
  distance: number;
  duration: number;
  nextFloor?: string;
  nextLandmark?: string;
  steps: Array<{ floor: string; landmark: string; distance: number }>;
};

// Mock data
const mockSpots: Spot[] = [
  { 
    id: '2A', 
    name: '受付', 
    floor: '1F', 
    x: 30, 
    y: 40, 
    congestion: 'normal', 
    category: '案内',
    tags: ['案内所', '配布物'],
    relatedEvents: 2,
  },
  { 
    id: '2', 
    name: '講義室A', 
    floor: '1F', 
    x: 50, 
    y: 50, 
    congestion: 'busy', 
    category: '教室',
    tags: ['大教室', '収容200名'],
    relatedEvents: 3,
  },
  { 
    id: '3', 
    name: '図書館', 
    floor: '2F', 
    x: 40, 
    y: 35, 
    congestion: 'empty', 
    category: '施設',
    tags: ['静か', '自習可'],
    relatedEvents: 0,
  },
  { 
    id: '4', 
    name: 'カフェテリア', 
    floor: '2F', 
    x: 60, 
    y: 60, 
    congestion: 'full', 
    category: '食堂',
    tags: ['学食', '休憩'],
    relatedEvents: 1,
  },
  { 
    id: '5', 
    name: '階段A', 
    floor: '1F', 
    x: 70, 
    y: 30, 
    congestion: 'normal', 
    category: '移動',
    tags: ['移動'],
    relatedEvents: 0,
  },
  { 
    id: '6', 
    name: '階段A', 
    floor: '2F', 
    x: 70, 
    y: 30, 
    congestion: 'normal', 
    category: '移動',
    tags: ['移動'],
    relatedEvents: 0,
  },
  { 
    id: '7', 
    name: '入口', 
    floor: '1F', 
    x: 20, 
    y: 60, 
    congestion: 'busy', 
    category: '案内',
    tags: ['正門', '集合場所'],
    relatedEvents: 1,
  },
  { 
    id: '8', 
    name: '体育館', 
    floor: 'B1', 
    x: 50, 
    y: 50, 
    congestion: 'empty', 
    category: '施設',
    tags: ['広い', 'イベント会場'],
    relatedEvents: 0,
  },
  { 
    id: '9', 
    name: '実験室B', 
    floor: '3F', 
    x: 45, 
    y: 45, 
    congestion: 'normal', 
    category: '教室',
    tags: ['少人数', '実習可'],
    relatedEvents: 1,
  },
  { 
    id: '10', 
    name: 'ラウンジ', 
    floor: '3F', 
    x: 65, 
    y: 55, 
    congestion: 'empty', 
    category: '施設',
    tags: ['休憩', 'Wi-Fi'],
    relatedEvents: 0,
  },
];

export default function App() {
  const [activeTab, setActiveTab] = useState<'home' | 'map' | 'events'>('home');
  const [selectedEvent, setSelectedEvent] = useState<Event | undefined>();
  const [isEventSheetOpen, setIsEventSheetOpen] = useState(false);
  const [isSupportOpen, setIsSupportOpen] = useState(false);
  const [supportPickMode, setSupportPickMode] = useState(false);
  const [supportPickedSpotName, setSupportPickedSpotName] = useState<string | undefined>();
  const [mapFocusSpotId, setMapFocusSpotId] = useState<string | undefined>();
  const [mapFocusSpotName, setMapFocusSpotName] = useState<string | undefined>();
  
  const handleOpenMap = () => {
    setActiveTab('map');
  };
  
  const handleEventClick = (event: Event) => {
    setSelectedEvent(event);
    setIsEventSheetOpen(true);
  };
  
  const handleSpotClick = (spot: Spot) => {
    setActiveTab('map');
    // The MapScreen will handle showing the spot details
  };

  const handleStartSupportMapPick = () => {
    setSupportPickedSpotName(undefined);
    setSupportPickMode(true);
    setActiveTab('map');
  };

  const handleSupportPickSpot = (spot: Spot) => {
    setSupportPickMode(false);
    setSupportPickedSpotName(spot.name);
    setIsSupportOpen(true);
  };

  const handleOpenSpotOnMap = (target: { spotId?: string; spotName?: string }) => {
    setMapFocusSpotId(target.spotId);
    setMapFocusSpotName(target.spotName);
    setActiveTab('map');
  };
  
  const handleTabChange = (tab: string) => {
    setActiveTab(tab as 'home' | 'map' | 'events');
  };
  
  return (
    <div 
      className="relative w-full overflow-hidden h-screen supports-[height:100dvh]:h-dvh"
      style={{ 
        backgroundColor: 'var(--background)',
        maxWidth: '390px',
        margin: '0 auto',
      }}
    >
      {/* Screen content */}
      <div className="h-full">
        {activeTab === 'home' && (
          <HomeScreen
            onOpenMap={handleOpenMap}
            onEventClick={handleEventClick}
            onSpotClick={handleSpotClick}
          />
        )}
        
        {activeTab === 'map' && (
          <MapScreen
            spots={mockSpots}
            onSpotClick={handleSpotClick}
            supportPickMode={supportPickMode}
            onSupportPickSpot={handleSupportPickSpot}
            focusSpotId={mapFocusSpotId}
            focusSpotName={mapFocusSpotName}
          />
        )}
        
        {activeTab === 'events' && (
          <EventsScreen
            onEventClick={handleEventClick}
            onOpenMap={handleOpenMap}
          />
        )}
      </div>
      
      {/* Bottom Navigation */}
      <BottomNav
        activeTab={activeTab}
        onTabChange={handleTabChange}
      />

      {/* Floating Support Button */}
      <motion.button
        onClick={() => setIsSupportOpen(true)}
        className="absolute right-4 z-[70] w-14 h-14 rounded-full flex items-center justify-center"
        style={{
          bottom: '96px',
          backgroundColor: 'var(--primary)',
          color: 'var(--primary-foreground)',
          boxShadow: 'var(--elev-3)',
        }}
        whileTap={{ scale: 0.95 }}
        title="サポート"
      >
        <Sparkles size={22} />
      </motion.button>

      {/* Support Sheet */}
      <SupportSheet
        isOpen={isSupportOpen}
        onClose={() => setIsSupportOpen(false)}
        onStartMapPick={handleStartSupportMapPick}
        onOpenSpotOnMap={handleOpenSpotOnMap}
        pickedSpotName={supportPickedSpotName}
      />
      
      {/* Event Detail Bottom Sheet */}
      {selectedEvent && (
        <div className="absolute inset-0 z-50 pointer-events-none">
          <div 
            className="absolute inset-0 bg-black/20 pointer-events-auto"
            onClick={() => setIsEventSheetOpen(false)}
            style={{ display: isEventSheetOpen ? 'block' : 'none' }}
          />
          <div 
            className="absolute left-0 right-0 bottom-0 rounded-t-3xl pointer-events-auto transition-transform duration-300 flex flex-col"
            style={{
              backgroundColor: 'var(--surface)',
              boxShadow: 'var(--elev-3)',
              transform: isEventSheetOpen ? 'translateY(0)' : 'translateY(100%)',
              maxHeight: '60vh',
            }}
          >
            {/* Handle */}
            <div className="flex justify-center pt-3 pb-2">
              <div 
                className="w-10 h-1 rounded-full"
                style={{ backgroundColor: 'var(--outline)' }}
              />
            </div>
            
            <div className="px-4 overflow-y-auto flex-1">
              <div className="space-y-4 py-2">
                {/* Event header */}
                <div className="flex items-start justify-between">
                  <div className="flex-1 min-w-0">
                    <h3 className="font-medium mb-2" style={{ color: 'var(--text)' }}>
                      {selectedEvent.title}
                    </h3>
                    <div className="flex items-center gap-3 text-sm mb-3" style={{ color: 'var(--muted-foreground)' }}>
                      <div className="flex items-center gap-1">
                        <span className="tabular-nums">{selectedEvent.time}</span>
                        {selectedEvent.endTime && <span> - {selectedEvent.endTime}</span>}
                      </div>
                    </div>
                    <div className="flex items-center gap-2 text-sm mb-3" style={{ color: 'var(--muted-foreground)' }}>
                      <span>{selectedEvent.location}</span>
                      {selectedEvent.floor && (
                        <>
                          <span>·</span>
                          <span>{selectedEvent.floor}</span>
                        </>
                      )}
                    </div>
                    
                    {/* Tags */}
                    <div className="flex flex-wrap gap-2 mb-4">
                      <span
                        className="px-2 py-1 rounded-lg text-xs"
                        style={{
                          backgroundColor: 'var(--primary-weak)',
                          color: 'var(--primary)',
                        }}
                      >
                        {selectedEvent.department}
                      </span>
                      {selectedEvent.category && (
                        <span
                          className="px-2 py-1 rounded-lg text-xs"
                          style={{
                            backgroundColor: 'var(--muted)',
                            color: 'var(--text)',
                          }}
                        >
                          {selectedEvent.category}
                        </span>
                      )}
                    </div>
                    
                    {/* Description */}
                    {selectedEvent.description && (
                      <p className="text-sm" style={{ color: 'var(--text)' }}>
                        {selectedEvent.description}
                      </p>
                    )}
                  </div>
                  <button
                    onClick={() => setIsEventSheetOpen(false)}
                    className="p-2 rounded-full transition-colors hover:bg-[--state-hover] flex-shrink-0 ml-2"
                  >
                    <span style={{ fontSize: '20px', color: 'var(--text)' }}>×</span>
                  </button>
                </div>
              </div>
            </div>
            
            {/* Action button - fixed at bottom */}
            <div className="px-4 py-4 border-t flex-shrink-0" style={{ borderColor: 'var(--outline)' }}>
              <button
                onClick={() => {
                  setIsEventSheetOpen(false);
                  setActiveTab('map');
                }}
                className="w-full py-3 rounded-2xl font-medium transition-colors"
                style={{
                  backgroundColor: 'var(--primary)',
                  color: 'var(--primary-foreground)',
                }}
              >
                マップで見る
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
