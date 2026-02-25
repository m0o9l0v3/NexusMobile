import { useState } from 'react';
import { motion, AnimatePresence } from 'motion/react';
import { Clock, MapPin, Filter, ArrowRight, Map as MapIcon } from 'lucide-react';

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

type EventsScreenProps = {
  onEventClick: (event: Event) => void;
  onOpenMap?: () => void;
  events?: Event[];
};

type FilterOption = {
  id: string;
  label: string;
};

const categories = ['全て', '説明会', 'ツアー', '模擬授業', '相談会'];
const departments = ['全体', '工学部', '情報学部', '理学部', '医学部'];

const events: Event[] = [
  {
    id: '1',
    title: '受付開始',
    time: '09:00',
    endTime: '09:30',
    location: '受付',
    floor: '1F',
    department: '全体',
    category: '案内',
    description: '受付でパンフレットと参加証をお渡しします',
  },
  {
    id: '2',
    title: '工学部説明会',
    time: '10:00',
    endTime: '11:00',
    location: '講義室A',
    floor: '1F',
    department: '工学部',
    category: '説明会',
    description: '工学部の特徴やカリキュラムについて詳しくご説明します',
  },
  {
    id: '3',
    title: 'キャンパスツアー (第1回)',
    time: '10:30',
    endTime: '11:30',
    location: '受付集合',
    floor: '1F',
    department: '全体',
    category: 'ツアー',
    description: '学生スタッフがキャンパス内をご案内します',
  },
  {
    id: '4',
    title: '情報学部説明会',
    time: '11:00',
    endTime: '12:00',
    location: '講義室B',
    floor: '2F',
    department: '情報学部',
    category: '説明会',
    description: 'AI・データサイエンスなど最新の研究をご紹介',
  },
  {
    id: '5',
    title: 'ランチタイム',
    time: '12:00',
    endTime: '13:00',
    location: 'カフェテリア',
    floor: '2F',
    department: '全体',
    category: '休憩',
    description: '学食体験ができます（無料券配布）',
  },
  {
    id: '6',
    title: '模擬授業：AI入門',
    time: '13:00',
    endTime: '14:00',
    location: '実験室B',
    floor: '3F',
    department: '情報学部',
    category: '模擬授業',
    description: '実際の授業を体験できます',
  },
  {
    id: '7',
    title: '個別相談会',
    time: '14:00',
    endTime: '16:00',
    location: '相談室',
    floor: '2F',
    department: '全体',
    category: '相談会',
    description: '入試や学生生活について個別にご相談いただけます',
  },
];

export function EventsScreen({ onEventClick, onOpenMap, events: remoteEvents }: EventsScreenProps) {
  const [selectedCategory, setSelectedCategory] = useState('全て');
  const [selectedDepartment, setSelectedDepartment] = useState('全体');
  const [isDepartmentFilterOpen, setIsDepartmentFilterOpen] = useState(false);
  
  const sourceEvents = remoteEvents ?? events;

  const filteredEvents = sourceEvents.filter(event => {
    if (selectedCategory !== '全て' && event.category !== selectedCategory) return false;
    if (selectedDepartment !== '全体' && event.department !== selectedDepartment) return false;
    return true;
  });
  
  // Group events by hour
  const groupedEvents = filteredEvents.reduce((acc, event) => {
    const hour = event.time.split(':')[0];
    if (!acc[hour]) acc[hour] = [];
    acc[hour].push(event);
    return acc;
  }, {} as Record<string, Event[]>);
  
  return (
    <div className="h-full flex flex-col relative">
      {/* Header with filters */}
      <div 
        className="flex-shrink-0 px-4 py-4 border-b"
        style={{ 
          backgroundColor: 'var(--surface)',
          borderColor: 'var(--outline)',
        }}
      >
        <div className="flex items-center justify-between mb-3">
          <h1 style={{ color: 'var(--text)' }}>イベント</h1>
        </div>
        
        {/* Category chips */}
        <div className="flex gap-2 overflow-x-auto pb-2 -mx-4 px-4 scrollbar-hide">
          {categories.map((category) => (
            <button
              key={category}
              onClick={() => setSelectedCategory(category)}
              className="px-3 py-1.5 rounded-full text-xs font-medium whitespace-nowrap transition-colors"
              style={{
                backgroundColor: selectedCategory === category ? 'var(--primary)' : 'var(--muted)',
                color: selectedCategory === category ? 'var(--primary-foreground)' : 'var(--text)',
              }}
            >
              {category}
            </button>
          ))}
        </div>
      </div>
      
      {/* Floating department filter button */}
      <div className="absolute right-4 z-20" style={{ top: '130px' }}>
        <motion.button
          onClick={() => setIsDepartmentFilterOpen(!isDepartmentFilterOpen)}
          className="w-12 h-12 rounded-full flex items-center justify-center"
          style={{
            backgroundColor: 'var(--surface)',
            boxShadow: 'var(--elev-2)',
          }}
          whileTap={{ scale: 0.9 }}
        >
          <Filter size={20} style={{ color: isDepartmentFilterOpen ? 'var(--primary)' : 'var(--text)' }} />
        </motion.button>
        
        {/* Department filter dropdown */}
        <AnimatePresence>
          {isDepartmentFilterOpen && (
            <motion.div
              initial={{ opacity: 0, y: -10 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: -10 }}
              className="absolute right-0 mt-2 p-3 rounded-2xl"
              style={{
                backgroundColor: 'var(--surface)',
                boxShadow: 'var(--elev-2)',
                width: '200px',
              }}
            >
              <div className="text-xs font-medium mb-2" style={{ color: 'var(--text)' }}>
                学部フィルタ
              </div>
              <div className="space-y-1">
                {departments.map((dept) => (
                  <button
                    key={dept}
                    onClick={() => {
                      setSelectedDepartment(dept);
                      setIsDepartmentFilterOpen(false);
                    }}
                    className="w-full px-3 py-2 rounded-lg text-xs text-left transition-colors"
                    style={{
                      backgroundColor: selectedDepartment === dept ? 'var(--primary-weak)' : 'transparent',
                      color: selectedDepartment === dept ? 'var(--primary)' : 'var(--text)',
                    }}
                  >
                    {dept}
                  </button>
                ))}
              </div>
            </motion.div>
          )}
        </AnimatePresence>
      </div>
      
      {/* Events timeline */}
      <div className="flex-1 overflow-y-auto pb-bottom-nav">
        {Object.keys(groupedEvents).sort().map((hour) => (
          <div key={hour} className="px-4 py-4">
            {/* Time marker */}
            <div className="flex items-center gap-3 mb-3">
              <div 
                className="px-3 py-1 rounded-full text-sm font-medium tabular-nums"
                style={{
                  backgroundColor: 'var(--muted)',
                  color: 'var(--text)',
                }}
              >
                {hour}:00
              </div>
              <div className="h-px flex-1" style={{ backgroundColor: 'var(--outline)' }} />
            </div>
            
            {/* Events in this hour */}
            <div className="space-y-3">
              {groupedEvents[hour].map((event) => (
                <div
                  key={event.id}
                  className="w-full p-4 rounded-2xl"
                  style={{
                    backgroundColor: 'var(--surface)',
                    boxShadow: 'var(--elev-1)',
                  }}
                >
                  <motion.button
                    onClick={() => onEventClick(event)}
                    className="w-full text-left"
                    whileTap={{ scale: 0.98 }}
                  >
                    <div className="flex items-start gap-3">
                      {/* Time indicator */}
                      <div className="flex-shrink-0">
                        <div 
                          className="w-2 h-2 rounded-full mt-1.5"
                          style={{ backgroundColor: 'var(--primary)' }}
                        />
                      </div>
                      
                      {/* Content */}
                      <div className="flex-1 min-w-0">
                        <div className="flex items-start justify-between gap-2 mb-1">
                          <div className="font-medium" style={{ color: 'var(--text)' }}>
                            {event.title}
                          </div>
                          <div className="flex-shrink-0">
                            <span 
                              className="px-2 py-0.5 rounded text-[10px] font-medium"
                              style={{
                                backgroundColor: 'var(--muted)',
                                color: 'var(--muted-foreground)',
                              }}
                            >
                              {event.department}
                            </span>
                          </div>
                        </div>
                        
                        <div className="flex items-center gap-3 text-xs mb-2" style={{ color: 'var(--muted-foreground)' }}>
                          <div className="flex items-center gap-1 tabular-nums">
                            <Clock size={12} />
                            <span>{event.time} - {event.endTime ?? "--:--"}</span>
                          </div>
                          <div className="flex items-center gap-1">
                            <MapPin size={12} />
                            <span>{event.location}{event.floor ? ` (${event.floor})` : ""}</span>
                          </div>
                        </div>
                        
                        <p className="text-sm mb-2" style={{ color: 'var(--muted-foreground)' }}>
                          {event.description ?? ""}
                        </p>
                        
                        {/* Text link instead of button */}
                        {onOpenMap && (
                          <button
                            onClick={(e) => {
                              e.stopPropagation();
                              onOpenMap();
                            }}
                            className="inline-flex items-center gap-1 text-xs transition-opacity hover:opacity-70"
                            style={{ color: 'var(--primary)' }}
                          >
                            <MapIcon size={12} />
                            <span>マップで場所を見る</span>
                            <ArrowRight size={12} />
                          </button>
                        )}
                      </div>
                    </div>
                  </motion.button>
                </div>
              ))}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
