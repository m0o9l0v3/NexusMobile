import { LucideIcon, TrendingUp, TrendingDown } from 'lucide-react';

interface KPICardProps {
  title: string;
  value: string | number;
  delta?: string;
  deltaType?: 'increase' | 'decrease';
  icon: LucideIcon;
  subtitle?: string;
}

export function KPICard({ title, value, delta, deltaType, icon: Icon, subtitle }: KPICardProps) {
  return (
    <div className="group relative overflow-hidden rounded-2xl border border-border bg-card p-6 shadow-sm transition-shadow hover:shadow-md">
      {/* Glassy effect */}
      <div className="absolute inset-0 bg-gradient-to-br from-white/40 to-transparent pointer-events-none"></div>
      
      <div className="relative">
        <div className="flex items-start justify-between">
          <div className="flex-1">
            <p className="text-sm text-muted-foreground mb-1">{title}</p>
            <p className="text-3xl font-semibold tracking-tight text-foreground">{value}</p>
            {subtitle && <p className="text-xs text-muted-foreground mt-1">{subtitle}</p>}
          </div>
          <div className="rounded-xl bg-primary/10 p-3 text-primary">
            <Icon className="h-6 w-6" />
          </div>
        </div>
        
        {delta && (
          <div className={`mt-4 flex items-center gap-1 text-sm ${
            deltaType === 'increase' ? 'text-green-600' : 'text-orange-600'
          }`}>
            {deltaType === 'increase' ? (
              <TrendingUp className="h-4 w-4" />
            ) : (
              <TrendingDown className="h-4 w-4" />
            )}
            <span>{delta}</span>
          </div>
        )}
      </div>
    </div>
  );
}
