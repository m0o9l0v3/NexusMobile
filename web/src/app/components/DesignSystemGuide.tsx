/**
 * Nexus 2D Map - Design System Guide
 * 
 * This component serves as a visual reference for the design system.
 * It demonstrates all the design tokens, components, and patterns used in the map feature.
 */

import { CongestionBadge } from '@/app/components/CongestionBadge';
import { RouteStepChip } from '@/app/components/RouteStepChip';

export function DesignSystemGuide() {
  return (
    <div className="p-6 space-y-8 max-w-4xl mx-auto">
      <div>
        <h1 className="mb-2">Nexus 2D Map Design System</h1>
        <p style={{ color: 'var(--muted-foreground)' }}>
          Material Design 3 準拠 · 青空トーン · モバイルファースト
        </p>
      </div>
      
      {/* Color Tokens */}
      <section>
        <h2 className="mb-4">Color Tokens</h2>
        <div className="grid grid-cols-2 gap-4">
          <div>
            <div className="text-sm font-medium mb-2">Sky Tones</div>
            <div className="space-y-2">
              <div className="flex items-center gap-3">
                <div className="w-12 h-12 rounded-lg" style={{ backgroundColor: 'var(--sky-0)' }} />
                <div className="text-sm">
                  <div className="font-medium">sky-0</div>
                  <div className="text-xs" style={{ color: 'var(--muted-foreground)' }}>#F4FBFF</div>
                </div>
              </div>
              <div className="flex items-center gap-3">
                <div className="w-12 h-12 rounded-lg" style={{ backgroundColor: 'var(--sky-1)' }} />
                <div className="text-sm">
                  <div className="font-medium">sky-1</div>
                  <div className="text-xs" style={{ color: 'var(--muted-foreground)' }}>#DDF1FF</div>
                </div>
              </div>
              <div className="flex items-center gap-3">
                <div className="w-12 h-12 rounded-lg" style={{ backgroundColor: 'var(--primary)' }} />
                <div className="text-sm">
                  <div className="font-medium">primary</div>
                  <div className="text-xs" style={{ color: 'var(--muted-foreground)' }}>#0B5ED7</div>
                </div>
              </div>
            </div>
          </div>
          
          <div>
            <div className="text-sm font-medium mb-2">Congestion Colors</div>
            <div className="space-y-2">
              <div className="flex items-center gap-3">
                <div className="w-12 h-12 rounded-lg" style={{ backgroundColor: 'var(--congestion-empty)' }} />
                <div className="text-sm">
                  <div className="font-medium">empty (空)</div>
                  <div className="text-xs" style={{ color: 'var(--muted-foreground)' }}>#34A853</div>
                </div>
              </div>
              <div className="flex items-center gap-3">
                <div className="w-12 h-12 rounded-lg" style={{ backgroundColor: 'var(--congestion-normal)' }} />
                <div className="text-sm">
                  <div className="font-medium">normal (普)</div>
                  <div className="text-xs" style={{ color: 'var(--muted-foreground)' }}>#FBBC04</div>
                </div>
              </div>
              <div className="flex items-center gap-3">
                <div className="w-12 h-12 rounded-lg" style={{ backgroundColor: 'var(--congestion-busy)' }} />
                <div className="text-sm">
                  <div className="font-medium">busy (混)</div>
                  <div className="text-xs" style={{ color: 'var(--muted-foreground)' }}>#FF9800</div>
                </div>
              </div>
              <div className="flex items-center gap-3">
                <div className="w-12 h-12 rounded-lg" style={{ backgroundColor: 'var(--congestion-full)' }} />
                <div className="text-sm">
                  <div className="font-medium">full (満)</div>
                  <div className="text-xs" style={{ color: 'var(--muted-foreground)' }}>#EA4335</div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>
      
      {/* Elevation */}
      <section>
        <h2 className="mb-4">Elevation</h2>
        <div className="grid grid-cols-3 gap-4">
          <div 
            className="p-6 rounded-2xl"
            style={{ 
              backgroundColor: 'var(--surface)',
              boxShadow: 'var(--elev-1)',
            }}
          >
            <div className="text-sm font-medium">elev-1</div>
            <div className="text-xs mt-1" style={{ color: 'var(--muted-foreground)' }}>
              Subtle elevation
            </div>
          </div>
          <div 
            className="p-6 rounded-2xl"
            style={{ 
              backgroundColor: 'var(--surface)',
              boxShadow: 'var(--elev-2)',
            }}
          >
            <div className="text-sm font-medium">elev-2</div>
            <div className="text-xs mt-1" style={{ color: 'var(--muted-foreground)' }}>
              Cards, floating UI
            </div>
          </div>
          <div 
            className="p-6 rounded-2xl"
            style={{ 
              backgroundColor: 'var(--surface)',
              boxShadow: 'var(--elev-3)',
            }}
          >
            <div className="text-sm font-medium">elev-3</div>
            <div className="text-xs mt-1" style={{ color: 'var(--muted-foreground)' }}>
              Modals, sheets
            </div>
          </div>
        </div>
      </section>
      
      {/* Components */}
      <section>
        <h2 className="mb-4">Components</h2>
        
        <div className="space-y-6">
          {/* Congestion Badges */}
          <div>
            <div className="text-sm font-medium mb-3">Congestion Badges</div>
            <div className="flex gap-3 items-center">
              <CongestionBadge level="empty" />
              <CongestionBadge level="normal" />
              <CongestionBadge level="busy" />
              <CongestionBadge level="full" />
              <span style={{ color: 'var(--muted-foreground)' }}>·</span>
              <CongestionBadge level="empty" variant="small" />
              <CongestionBadge level="normal" variant="small" />
              <CongestionBadge level="busy" variant="small" />
              <CongestionBadge level="full" variant="small" />
            </div>
          </div>
          
          {/* Route Step Chips */}
          <div>
            <div className="text-sm font-medium mb-3">Route Step Chips</div>
            <div className="flex gap-2 flex-wrap">
              <RouteStepChip label="次は2F" />
              <RouteStepChip label="階段A" />
              <RouteStepChip label="約3分" />
            </div>
          </div>
        </div>
      </section>
      
      {/* Typography */}
      <section>
        <h2 className="mb-4">Typography</h2>
        <div className="space-y-3">
          <div>
            <h1>Heading 1 - Noto Sans JP + Inter</h1>
            <div className="text-xs mt-1" style={{ color: 'var(--muted-foreground)' }}>
              Font weight: 500 (medium)
            </div>
          </div>
          <div>
            <h2>Heading 2 - Map titles</h2>
          </div>
          <div>
            <h3>Heading 3 - Section headers</h3>
          </div>
          <div>
            <p>Body text - 説明文やラベルに使用します。</p>
          </div>
          <div className="tabular-nums">
            <span className="text-sm">Tabular nums: 123.45m · 5分 · 12人</span>
          </div>
        </div>
      </section>
      
      {/* Spacing & Radius */}
      <section>
        <h2 className="mb-4">Spacing & Radius</h2>
        <div className="space-y-3">
          <div>
            <div className="text-sm font-medium mb-2">Corner Radius</div>
            <div className="flex gap-4">
              <div className="w-20 h-20 bg-[--primary]" style={{ borderRadius: '12px' }}>
                <div className="text-xs text-white p-2">12px<br/>Small</div>
              </div>
              <div className="w-20 h-20 bg-[--primary]" style={{ borderRadius: '16px' }}>
                <div className="text-xs text-white p-2">16px<br/>Medium</div>
              </div>
              <div className="w-20 h-20 bg-[--primary]" style={{ borderRadius: '24px' }}>
                <div className="text-xs text-white p-2">24px<br/>Large</div>
              </div>
            </div>
          </div>
        </div>
      </section>
      
      {/* Design Principles */}
      <section>
        <h2 className="mb-4">Design Principles</h2>
        <div className="grid grid-cols-2 gap-4">
          <div 
            className="p-4 rounded-2xl"
            style={{ backgroundColor: 'var(--muted)' }}
          >
            <div className="font-medium mb-2">軽量表現</div>
            <div className="text-sm" style={{ color: 'var(--muted-foreground)' }}>
              派手な色面積を避け、控えめな影と角丸で「浮いている」質感を表現
            </div>
          </div>
          <div 
            className="p-4 rounded-2xl"
            style={{ backgroundColor: 'var(--muted)' }}
          >
            <div className="font-medium mb-2">片手操作</div>
            <div className="text-sm" style={{ color: 'var(--muted-foreground)' }}>
              主要アクションは下部に配置。タップターゲットは最低44px
            </div>
          </div>
          <div 
            className="p-4 rounded-2xl"
            style={{ backgroundColor: 'var(--muted)' }}
          >
            <div className="font-medium mb-2">地図が主役</div>
            <div className="text-sm" style={{ color: 'var(--muted-foreground)' }}>
              UIは必要最小限。地図の視認性を最優先
            </div>
          </div>
          <div 
            className="p-4 rounded-2xl"
            style={{ backgroundColor: 'var(--muted)' }}
          >
            <div className="font-medium mb-2">静かな更新</div>
            <div className="text-sm" style={{ color: 'var(--muted-foreground)' }}>
              混雑情報は色の変化のみ。点滅や派手な通知は避ける
            </div>
          </div>
        </div>
      </section>
    </div>
  );
}
