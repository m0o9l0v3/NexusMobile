/**
 * トップ＝アプリの告知（#131）。QR の `?code=` もここに着地するが、値は使わず同じ案内を出す。
 * スマホは専用の配置（画面が先・App Store ボタンを下に固定）、PC は2カラム（2026-11-14 利用者決定）。
 */
import { useState } from 'react';
import { Label, Layout } from '../components/Layout';
import { mount } from './mount';

// App Store の URL は公開後に差し替える
const appStoreUrl = undefined as string | undefined;

const sections = [
  { n: '01', title: '開発状況', body: '機能ごとの進み具合', href: '/development/' },
  { n: '02', title: 'サーバー状況', body: 'サーバーの応答とお知らせ', href: '/status/' },
  { n: '03', title: '技術説明', body: 'Nexus を支える設計と技術', href: '/tech/' },
];

function AppStoreButton({ className = '' }: { className?: string }) {
  const cls = `inline-flex items-center justify-center rounded-full bg-accent px-6 py-3.5 text-sm font-bold text-on-accent ${className}`;
  return appStoreUrl ? (
    <a href={appStoreUrl} className={cls}>
      App Store で見る
    </a>
  ) : (
    <span className={cls} aria-disabled="true">
      App Store で見る
    </span>
  );
}

function Top() {
  // 承認済みの画面画像（web/public/app-shots/）がまだ無い間は、画像の枠ごと出さない
  const [shotMissing, setShotMissing] = useState(false);
  return (
    <Layout current="top" mobileBottomBar={<AppStoreButton className="w-full py-[15px] text-[15px]" />}>
      <section className="flex flex-col pb-10 md:grid md:grid-cols-12 md:gap-6 md:pt-12">
        {/* 画面：スマホでは最初に大きく見せ、下側を背景色に溶かす。PC では右カラム */}
        {!shotMissing && (
          <div className="relative order-first h-[440px] overflow-hidden md:order-last md:col-span-5 md:h-[600px] md:overflow-visible">
            <div className="flex h-full justify-center pt-7 md:items-center md:pt-0">
              {/* 承認済みの画面を公式の枠（iPhone 17 Pro・ディープブルー）にはめ込んだ画像。ダークではダークの画面に切り替える */}
              <picture>
                <source srcSet="/app-shots/hero-dark.png" media="(prefers-color-scheme: dark)" />
                <img
                  src="/app-shots/hero-light.png"
                  alt="Nexus のマップ画面"
                  onError={() => setShotMissing(true)}
                  className="w-[230px] drop-shadow-[0_20px_30px_rgba(14,14,14,0.18)] md:h-[560px] md:w-auto"
                />
              </picture>
            </div>
            <div className="pointer-events-none absolute inset-x-0 bottom-0 h-32 bg-gradient-to-b from-transparent to-bg md:hidden" />
          </div>
        )}
        <div className={`relative px-5 md:col-span-7 md:mt-0 md:px-0 ${shotMissing ? 'pt-10' : '-mt-5'}`}>
          <Label>OPEN CAMPUS GUIDE / iOS / 2026</Label>
          <h1 className="mt-3 mb-4 text-[44px] font-black leading-[1.05] tracking-[-0.03em] md:mt-6 md:mb-8 md:text-[84px]">
            迷わない
            <br />
            <span className="text-accent">オープン</span>
            <br />
            キャンパス。
          </h1>
          <p className="max-w-[460px] text-sm leading-[1.9] text-sub md:text-[15px] md:leading-[1.95]">
            建物の場所、今日のイベント、学校生活の案内を iPhone で。通信が途切れても地図は描けます。
            <span className="hidden md:inline">その仕組みも、このサイトで公開しています。</span>
          </p>
          <div className="mt-8 hidden flex-wrap items-center gap-5 md:flex">
            <AppStoreButton />
            <a href="/tech/" className="text-sm hover:underline">
              技術説明を読む →
            </a>
          </div>
        </div>
      </section>

      <nav aria-label="ほかのページ" className="border-b border-rule md:grid md:grid-cols-12 md:gap-6 md:border-b-0 md:border-t md:pt-5 md:pb-0">
        {sections.map((s) => (
          <a
            key={s.n}
            href={s.href}
            className="group flex items-center gap-3 border-t border-rule px-5 py-[18px] md:col-span-4 md:block md:border-t-0 md:p-0"
          >
            <span className="w-11 text-[22px] font-extrabold tracking-[-0.03em] text-numeral md:block md:w-auto md:text-[40px]">{s.n}</span>
            <span className="flex-1">
              <span className="block text-base font-bold group-hover:text-accent md:mt-1 md:text-lg">{s.title}</span>
              <span className="mt-0.5 block text-xs text-muted md:mt-1.5 md:text-[13px]">{s.body}</span>
            </span>
            <span aria-hidden="true" className="text-lg md:hidden">
              →
            </span>
          </a>
        ))}
      </nav>

    </Layout>
  );
}

mount(<Top />);
