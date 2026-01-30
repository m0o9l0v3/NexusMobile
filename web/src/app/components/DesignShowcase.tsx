/**
 * Design Showcase Component
 * 
 * Visual demonstration of all Nexus design system components and patterns.
 * This can be viewed by temporarily replacing App.tsx content.
 */

import { useState } from 'react';
import { motion } from 'motion/react';
import { MapPin, Navigation, Clock, Star, Heart, Filter, Search, Home, Map, Calendar } from 'lucide-react';
import { CongestionBadge } from '@/app/components/CongestionBadge';
import { RouteStepChip } from '@/app/components/RouteStepChip';
import { FloorSwitch } from '@/app/components/FloorSwitch';

export function DesignShowcase() {
  const [currentFloor, setCurrentFloor] = useState('1F');
  const [activeTab, setActiveTab] = useState('home');
  
  return (
    <div className="max-w-md mx-auto h-screen overflow-y-auto pb-24 bg-gradient-to-b from-[--sky-1] to-[--sky-0]">
      <div className="p-6 space-y-8">
        {/* Header */}
        <div>
          <h1 className="mb-2" style={{ color: 'var(--text)' }}>
            Nexus Design System
          </h1>
          <p className="text-sm" style={{ color: 'var(--muted-foreground)' }}>
            Material Design 3 · 青空トーン · モバイルファースト
          </p>
        </div>
        
        {/* Color Palette */}
        <section>
          <h2 className="mb-4" style={{ color: 'var(--text)' }}>Color Palette</h2>
          <div className="space-y-3">
            {/* Sky Tones */}
            <div>
              <div className="text-sm font-medium mb-2" style={{ color: 'var(--text)' }}>
                Sky Tones
              </div>
              <div className="grid grid-cols-3 gap-2">
                <div className="space-y-1">
                  <div className="h-16 rounded-xl" style={{ backgroundColor: 'var(--sky-0)' }} />
                  <div className="text-xs text-center" style={{ color: 'var(--muted-foreground)' }}>
                    sky-0
                  </div>
                </div>
                <div className="space-y-1">
                  <div className="h-16 rounded-xl" style={{ backgroundColor: 'var(--sky-1)' }} />
                  <div className="text-xs text-center" style={{ color: 'var(--muted-foreground)' }}>
                    sky-1
                  </div>
                </div>
                <div className="space-y-1">
                  <div className="h-16 rounded-xl" style={{ backgroundColor: 'var(--primary)' }} />
                  <div className="text-xs text-center" style={{ color: 'var(--muted-foreground)' }}>
                    primary
                  </div>
                </div>
              </div>
            </div>
            
            {/* Congestion Colors */}
            <div>
              <div className="text-sm font-medium mb-2" style={{ color: 'var(--text)' }}>
                Congestion Colors
              </div>
              <div className="grid grid-cols-4 gap-2">
                {['empty', 'normal', 'busy', 'full'].map((level) => (
                  <div key={level} className="space-y-1">
                    <div 
                      className="h-16 rounded-xl" 
                      style={{ backgroundColor: `var(--congestion-${level})` }} 
                    />
                    <div className="text-xs text-center capitalize" style={{ color: 'var(--muted-foreground)' }}>
                      {level}
                    </div>
                  </div>
                ))}
              </div>
            </div>
          </div>
        </section>
        
        {/* Elevation */}
        <section>
          <h2 className="mb-4" style={{ color: 'var(--text)' }}>Elevation System</h2>
          <div className="space-y-4">
            {[1, 2, 3].map((level) => (
              <div
                key={level}
                className="p-4 rounded-2xl"
                style={{
                  backgroundColor: 'var(--surface)',
                  boxShadow: `var(--elev-${level})`,
                }}
              >
                <div className="font-medium" style={{ color: 'var(--text)' }}>
                  Elevation {level}
                </div>
                <div className="text-xs mt-1" style={{ color: 'var(--muted-foreground)' }}>
                  {level === 1 && 'Resting cards, list items'}
                  {level === 2 && 'Floating buttons, search bars'}
                  {level === 3 && 'Bottom sheets, modals, dialogs'}
                </div>
              </div>
            ))}
          </div>
        </section>
        
        {/* Congestion Badges */}
        <section>
          <h2 className="mb-4" style={{ color: 'var(--text)' }}>Congestion Badges</h2>
          <div className="space-y-3">
            <div>
              <div className="text-sm mb-2" style={{ color: 'var(--muted-foreground)' }}>
                Default Size
              </div>
              <div className="flex gap-2 flex-wrap">
                <CongestionBadge level="empty" />
                <CongestionBadge level="normal" />
                <CongestionBadge level="busy" />
                <CongestionBadge level="full" />
              </div>
            </div>
            <div>
              <div className="text-sm mb-2" style={{ color: 'var(--muted-foreground)' }}>
                Small Variant
              </div>
              <div className="flex gap-2 flex-wrap">
                <CongestionBadge level="empty" variant="small" />
                <CongestionBadge level="normal" variant="small" />
                <CongestionBadge level="busy" variant="small" />
                <CongestionBadge level="full" variant="small" />
              </div>
            </div>
          </div>
        </section>
        
        {/* Route Step Chips */}
        <section>
          <h2 className="mb-4" style={{ color: 'var(--text)' }}>Route Step Chips</h2>
          <div className="flex gap-2 flex-wrap">
            <RouteStepChip label="1F" />
            <RouteStepChip label="階段A" />
            <RouteStepChip label="2F" />
            <RouteStepChip label="講義室へ" />
          </div>
        </section>
        
        {/* Floor Switch */}
        <section>
          <h2 className="mb-4" style={{ color: 'var(--text)' }}>Floor Switcher</h2>
          <FloorSwitch
            floors={['Outdoor', 'B1', '1F', '2F', '3F']}
            currentFloor={currentFloor}
            onFloorChange={setCurrentFloor}
          />
        </section>
        
        {/* Buttons */}
        <section>
          <h2 className="mb-4" style={{ color: 'var(--text)' }}>Buttons</h2>
          <div className="space-y-3">
            {/* Primary */}
            <motion.button
              className="w-full py-3 px-4 rounded-2xl font-medium"
              style={{
                backgroundColor: 'var(--primary)',
                color: 'var(--primary-foreground)',
              }}
              whileTap={{ scale: 0.98 }}
            >
              Primary Button
            </motion.button>
            
            {/* Secondary */}
            <motion.button
              className="w-full py-3 px-4 rounded-2xl font-medium"
              style={{
                backgroundColor: 'var(--muted)',
                color: 'var(--text)',
              }}
              whileTap={{ scale: 0.98 }}
            >
              Secondary Button
            </motion.button>
            
            {/* Icon Buttons */}
            <div className="flex gap-2">
              <motion.button
                className="w-12 h-12 rounded-full flex items-center justify-center"
                style={{
                  backgroundColor: 'var(--surface)',
                  boxShadow: 'var(--elev-2)',
                }}
                whileTap={{ scale: 0.9 }}
              >
                <Search size={20} style={{ color: 'var(--text)' }} />
              </motion.button>
              <motion.button
                className="w-12 h-12 rounded-full flex items-center justify-center"
                style={{
                  backgroundColor: 'var(--surface)',
                  boxShadow: 'var(--elev-2)',
                }}
                whileTap={{ scale: 0.9 }}
              >
                <Filter size={20} style={{ color: 'var(--text)' }} />
              </motion.button>
            </div>
          </div>
        </section>
        
        {/* Cards */}
        <section>
          <h2 className="mb-4" style={{ color: 'var(--text)' }}>Cards</h2>
          <div className="space-y-3">
            {/* Event Card */}
            <motion.div
              className="p-4 rounded-2xl"
              style={{
                backgroundColor: 'var(--surface)',
                boxShadow: 'var(--elev-1)',
              }}
              whileTap={{ scale: 0.98 }}
            >
              <div className="flex items-start gap-3">
                <div 
                  className="px-3 py-1 rounded-full text-xs font-medium tabular-nums flex-shrink-0"
                  style={{
                    backgroundColor: 'var(--primary-weak)',
                    color: 'var(--primary)',
                  }}
                >
                  11:00
                </div>
                <div className="flex-1">
                  <div className="font-medium mb-1" style={{ color: 'var(--text)' }}>
                    工学部説明会
                  </div>
                  <div className="flex items-center gap-2 text-xs" style={{ color: 'var(--muted-foreground)' }}>
                    <MapPin size={12} />
                    <span>講義室A</span>
                  </div>
                </div>
              </div>
            </motion.div>
            
            {/* Spot Card */}
            <motion.div
              className="p-4 rounded-2xl"
              style={{
                backgroundColor: 'var(--surface)',
                boxShadow: 'var(--elev-1)',
              }}
              whileTap={{ scale: 0.98 }}
            >
              <div className="flex items-start justify-between mb-2">
                <div 
                  className="w-10 h-10 rounded-full flex items-center justify-center"
                  style={{ backgroundColor: 'var(--muted)' }}
                >
                  <MapPin size={18} style={{ color: 'var(--primary)' }} />
                </div>
                <CongestionBadge level="normal" variant="small" />
              </div>
              <div className="font-medium mb-1" style={{ color: 'var(--text)' }}>
                図書館
              </div>
              <div className="text-xs" style={{ color: 'var(--muted-foreground)' }}>
                施設見学 · 2F
              </div>
            </motion.div>
          </div>
        </section>
        
        {/* Action Grid */}
        <section>
          <h2 className="mb-4" style={{ color: 'var(--text)' }}>Action Grid</h2>
          <div className="grid grid-cols-3 gap-2">
            <button
              className="flex flex-col items-center gap-2 py-3 rounded-2xl"
              style={{
                backgroundColor: 'var(--primary)',
                color: 'var(--primary-foreground)',
              }}
            >
              <Navigation size={20} />
              <span className="text-xs font-medium">案内</span>
            </button>
            <button
              className="flex flex-col items-center gap-2 py-3 rounded-2xl"
              style={{
                backgroundColor: 'var(--muted)',
                color: 'var(--text)',
              }}
            >
              <Star size={20} />
              <span className="text-xs font-medium">イベント</span>
            </button>
            <button
              className="flex flex-col items-center gap-2 py-3 rounded-2xl"
              style={{
                backgroundColor: 'var(--muted)',
                color: 'var(--text)',
              }}
            >
              <Heart size={20} />
              <span className="text-xs font-medium">保存</span>
            </button>
          </div>
        </section>
        
        {/* Bottom Navigation Preview */}
        <section>
          <h2 className="mb-4" style={{ color: 'var(--text)' }}>Bottom Navigation</h2>
          <div 
            className="p-2 rounded-2xl border"
            style={{
              backgroundColor: 'var(--surface)',
              borderColor: 'var(--outline)',
            }}
          >
            <div className="flex items-center justify-around">
              {[
                { id: 'home', label: 'ホーム', icon: <Home size={22} /> },
                { id: 'map', label: 'マップ', icon: <Map size={22} /> },
                { id: 'events', label: 'イベント', icon: <Calendar size={22} /> },
              ].map((item) => {
                const isActive = item.id === activeTab;
                return (
                  <button
                    key={item.id}
                    onClick={() => setActiveTab(item.id)}
                    className="relative flex flex-col items-center gap-1 py-2 px-6 rounded-2xl flex-1"
                    style={{
                      color: isActive ? 'var(--primary)' : 'var(--muted-foreground)',
                    }}
                  >
                    {isActive && (
                      <motion.div
                        layoutId="showcase-nav-bg"
                        className="absolute inset-0 rounded-2xl"
                        style={{ backgroundColor: 'var(--primary-weak)' }}
                      />
                    )}
                    <div className="relative z-10 flex flex-col items-center gap-1">
                      {item.icon}
                      <span className="text-[11px] font-medium">{item.label}</span>
                    </div>
                  </button>
                );
              })}
            </div>
          </div>
        </section>
        
        {/* Typography */}
        <section>
          <h2 className="mb-4" style={{ color: 'var(--text)' }}>Typography</h2>
          <div className="space-y-3">
            <div>
              <h1>Heading 1 - ページタイトル</h1>
              <div className="text-xs mt-1" style={{ color: 'var(--muted-foreground)' }}>
                24px / 1.5 / 500
              </div>
            </div>
            <div>
              <h2>Heading 2 - セクションヘッダー</h2>
              <div className="text-xs mt-1" style={{ color: 'var(--muted-foreground)' }}>
                20px / 1.5 / 500
              </div>
            </div>
            <div>
              <h3>Heading 3 - カードタイトル</h3>
              <div className="text-xs mt-1" style={{ color: 'var(--muted-foreground)' }}>
                18px / 1.5 / 500
              </div>
            </div>
            <div>
              <p>Body - 本文テキスト。説明やラベルに使用します。</p>
              <div className="text-xs mt-1" style={{ color: 'var(--muted-foreground)' }}>
                16px / 1.5 / 400
              </div>
            </div>
            <div>
              <span className="text-sm">Small - メタ情報や補足テキスト</span>
              <div className="text-xs mt-1" style={{ color: 'var(--muted-foreground)' }}>
                14px / 1.5 / 400
              </div>
            </div>
            <div className="tabular-nums">
              <span className="text-sm">Tabular: 123.45m · 5分 · 12人</span>
              <div className="text-xs mt-1" style={{ color: 'var(--muted-foreground)' }}>
                font-variant-numeric: tabular-nums
              </div>
            </div>
          </div>
        </section>
        
        {/* Design Principles */}
        <section>
          <h2 className="mb-4" style={{ color: 'var(--text)' }}>Design Principles</h2>
          <div className="grid grid-cols-1 gap-3">
            <div 
              className="p-4 rounded-2xl"
              style={{ backgroundColor: 'var(--muted)' }}
            >
              <div className="font-medium mb-2" style={{ color: 'var(--text)' }}>
                🌤️ 軽量表現
              </div>
              <div className="text-sm" style={{ color: 'var(--muted-foreground)' }}>
                派手な色面積を避け、控えめな影と角丸で「浮いている」質感を表現
              </div>
            </div>
            <div 
              className="p-4 rounded-2xl"
              style={{ backgroundColor: 'var(--muted)' }}
            >
              <div className="font-medium mb-2" style={{ color: 'var(--text)' }}>
                👆 片手操作
              </div>
              <div className="text-sm" style={{ color: 'var(--muted-foreground)' }}>
                主要アクションは下部に配置。タップターゲットは最低44px
              </div>
            </div>
            <div 
              className="p-4 rounded-2xl"
              style={{ backgroundColor: 'var(--muted)' }}
            >
              <div className="font-medium mb-2" style={{ color: 'var(--text)' }}>
                🗺️ 地図が主役
              </div>
              <div className="text-sm" style={{ color: 'var(--muted-foreground)' }}>
                UIは必要最小限。地図の視認性を最優先
              </div>
            </div>
            <div 
              className="p-4 rounded-2xl"
              style={{ backgroundColor: 'var(--muted)' }}
            >
              <div className="font-medium mb-2" style={{ color: 'var(--text)' }}>
                🔄 静かな更新
              </div>
              <div className="text-sm" style={{ color: 'var(--muted-foreground)' }}>
                混雑情報は色の変化のみ。点滅や派手な通知は避ける
              </div>
            </div>
          </div>
        </section>
      </div>
    </div>
  );
}
