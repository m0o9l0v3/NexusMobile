import { motion } from 'motion/react';
import { Map, Calendar, Navigation, ChevronRight } from 'lucide-react';

type WelcomeScreenProps = {
  onStart: () => void;
};

const features = [
  {
    icon: <Map size={32} />,
    title: 'キャンパスマップ',
    description: 'フロア別の詳細マップで目的地を簡単に探せます',
  },
  {
    icon: <Calendar size={32} />,
    title: 'イベント情報',
    description: 'タイムライン形式で開催イベントを確認できます',
  },
  {
    icon: <Navigation size={32} />,
    title: '経路案内',
    description: 'ステップバイステップで目的地まで案内します',
  },
];

export function WelcomeScreen({ onStart }: WelcomeScreenProps) {
  return (
    <div className="h-full flex flex-col bg-gradient-to-b from-[--sky-1] to-[--sky-0]">
      {/* Hero Section */}
      <div className="flex-1 flex flex-col items-center justify-center px-6 text-center">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.2 }}
          className="w-24 h-24 rounded-full mb-6 flex items-center justify-center"
          style={{
            backgroundColor: 'var(--primary)',
            boxShadow: 'var(--elev-3)',
          }}
        >
          <Map size={48} style={{ color: 'var(--primary-foreground)' }} />
        </motion.div>
        
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.3 }}
        >
          <h1 className="mb-3" style={{ color: 'var(--text)' }}>
            Nexusへようこそ
          </h1>
          <p className="text-sm mb-8" style={{ color: 'var(--muted-foreground)' }}>
            オープンキャンパスを<br />スムーズにご案内します
          </p>
        </motion.div>
        
        {/* Features */}
        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ delay: 0.5 }}
          className="w-full space-y-4 mb-8"
        >
          {features.map((feature, index) => (
            <motion.div
              key={feature.title}
              initial={{ opacity: 0, x: -20 }}
              animate={{ opacity: 1, x: 0 }}
              transition={{ delay: 0.6 + index * 0.1 }}
              className="flex items-start gap-4 p-4 rounded-2xl text-left"
              style={{
                backgroundColor: 'var(--surface)',
                boxShadow: 'var(--elev-1)',
              }}
            >
              <div 
                className="w-12 h-12 rounded-full flex items-center justify-center flex-shrink-0"
                style={{
                  backgroundColor: 'var(--primary-weak)',
                  color: 'var(--primary)',
                }}
              >
                {feature.icon}
              </div>
              <div className="flex-1 min-w-0">
                <div className="font-medium mb-1" style={{ color: 'var(--text)' }}>
                  {feature.title}
                </div>
                <div className="text-sm" style={{ color: 'var(--muted-foreground)' }}>
                  {feature.description}
                </div>
              </div>
            </motion.div>
          ))}
        </motion.div>
      </div>
      
      {/* CTA Section */}
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ delay: 0.9 }}
        className="px-6 pb-8 safe-area-inset-bottom"
      >
        <motion.button
          onClick={onStart}
          className="w-full py-4 px-6 rounded-3xl flex items-center justify-between font-medium"
          style={{
            backgroundColor: 'var(--primary)',
            color: 'var(--primary-foreground)',
            boxShadow: 'var(--elev-2)',
          }}
          whileTap={{ scale: 0.98 }}
        >
          <span>はじめる</span>
          <ChevronRight size={24} />
        </motion.button>
        
        <p className="text-xs text-center mt-4" style={{ color: 'var(--muted-foreground)' }}>
          位置情報の使用を許可すると、より正確な案内が可能です
        </p>
      </motion.div>
    </div>
  );
}
