import { motion } from 'motion/react';

export function LoadingState() {
  return (
    <div className="absolute inset-0 flex items-center justify-center">
      <div className="text-center">
        <motion.div
          className="w-12 h-12 mx-auto mb-4 rounded-full"
          style={{
            border: '3px solid var(--outline)',
            borderTopColor: 'var(--primary)',
          }}
          animate={{ rotate: 360 }}
          transition={{
            duration: 1,
            repeat: Infinity,
            ease: 'linear',
          }}
        />
        <p className="text-sm" style={{ color: 'var(--muted-foreground)' }}>
          マップを読み込んでいます...
        </p>
      </div>
    </div>
  );
}

export function SSEDisconnectedToast({ onReconnect }: { onReconnect: () => void }) {
  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      exit={{ opacity: 0, y: 20 }}
      className="absolute bottom-24 left-4 right-4 z-30"
    >
      <div
        className="p-4 rounded-2xl flex items-center justify-between"
        style={{
          backgroundColor: 'var(--surface)',
          boxShadow: 'var(--elev-3)',
          border: '1px solid var(--outline)',
        }}
      >
        <div className="flex-1">
          <p className="text-sm font-medium mb-1" style={{ color: 'var(--text)' }}>
            混雑情報の更新が停止しています
          </p>
          <p className="text-xs" style={{ color: 'var(--muted-foreground)' }}>
            再接続するには右のボタンをタップ
          </p>
        </div>
        <button
          onClick={onReconnect}
          className="ml-3 px-4 py-2 rounded-full text-sm font-medium transition-colors"
          style={{
            backgroundColor: 'var(--primary)',
            color: 'var(--primary-foreground)',
          }}
        >
          再接続
        </button>
      </div>
    </motion.div>
  );
}

export function EmptyState() {
  return (
    <div className="absolute inset-0 flex items-center justify-center p-8">
      <div className="text-center max-w-sm">
        <div 
          className="w-20 h-20 mx-auto mb-4 rounded-full flex items-center justify-center"
          style={{ backgroundColor: 'var(--muted)' }}
        >
          <svg width="40" height="40" viewBox="0 0 40 40" fill="none">
            <path
              d="M20 5L32 12V28L20 35L8 28V12L20 5Z"
              stroke="currentColor"
              strokeWidth="2"
              strokeLinecap="round"
              strokeLinejoin="round"
              style={{ color: 'var(--muted-foreground)' }}
            />
            <path
              d="M20 20L8 12M20 20L32 12M20 20V35"
              stroke="currentColor"
              strokeWidth="2"
              strokeLinecap="round"
              strokeLinejoin="round"
              style={{ color: 'var(--muted-foreground)' }}
            />
          </svg>
        </div>
        <h3 className="font-medium mb-2" style={{ color: 'var(--text)' }}>
          マップデータがありません
        </h3>
        <p className="text-sm" style={{ color: 'var(--muted-foreground)' }}>
          現在、表示できるマップ情報がありません
        </p>
      </div>
    </div>
  );
}
