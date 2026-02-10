type CongestionLevel = 'empty' | 'normal' | 'busy' | 'full';

type CongestionBadgeProps = {
  level: CongestionLevel;
  variant?: 'default' | 'small';
};

const congestionConfig = {
  empty: {
    label: '空',
    color: 'var(--congestion-empty)',
    bg: 'rgba(52, 168, 83, 0.1)',
  },
  normal: {
    label: '普',
    color: 'var(--congestion-normal)',
    bg: 'rgba(251, 188, 4, 0.1)',
  },
  busy: {
    label: '混',
    color: 'var(--congestion-busy)',
    bg: 'rgba(255, 152, 0, 0.1)',
  },
  full: {
    label: '満',
    color: 'var(--congestion-full)',
    bg: 'rgba(234, 67, 53, 0.1)',
  },
};

export function CongestionBadge({ level, variant = 'default' }: CongestionBadgeProps) {
  const config = congestionConfig[level];
  const isSmall = variant === 'small';
  
  return (
    <span
      className={`inline-flex items-center justify-center rounded-full font-medium ${
        isSmall ? 'px-1.5 py-0.5 text-[10px] min-w-[20px]' : 'px-2 py-0.5 text-xs min-w-[24px]'
      }`}
      style={{
        backgroundColor: config.bg,
        color: config.color,
        border: `1px solid ${config.color}`,
      }}
    >
      {config.label}
    </span>
  );
}
