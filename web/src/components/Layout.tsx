import { useEffect, useState, type ReactNode } from 'react';
import '../styles/index.css';

export type PageKey = 'top' | 'development' | 'status' | 'tech';

const navItems: { key: PageKey; label: string; href: string }[] = [
  { key: 'top', label: 'アプリ', href: '/' },
  { key: 'development', label: '開発状況', href: '/development/' },
  { key: 'status', label: 'サーバー状況', href: '/status/' },
  { key: 'tech', label: '技術説明', href: '/tech/' },
];

export function Layout({
  current,
  children,
  mobileBottomBar,
}: {
  current: PageKey;
  children: ReactNode;
  /** スマホだけ画面の下に固定して出すもの（トップの App Store ボタン）。 */
  mobileBottomBar?: ReactNode;
}) {
  const [menuOpen, setMenuOpen] = useState(false);

  useEffect(() => {
    if (!menuOpen) return;
    const onKey = (e: KeyboardEvent) => e.key === 'Escape' && setMenuOpen(false);
    document.addEventListener('keydown', onKey);
    // 画面を回すなどして PC 幅（md = 48rem）になったらメニューは md:hidden で消えるので、
    // 開いたままにせず閉じてスクロールの固定も外す。
    const pcWidth = window.matchMedia('(min-width: 48rem)');
    const onWidth = () => pcWidth.matches && setMenuOpen(false);
    onWidth();
    pcWidth.addEventListener('change', onWidth);
    document.body.style.overflow = 'hidden';
    return () => {
      document.removeEventListener('keydown', onKey);
      pcWidth.removeEventListener('change', onWidth);
      document.body.style.overflow = '';
    };
  }, [menuOpen]);

  return (
    <div className="mx-auto min-h-screen max-w-[1200px] md:px-10">
      <header className="flex h-14 items-center justify-between px-5 md:grid md:h-auto md:grid-cols-12 md:items-baseline md:gap-6 md:px-0 md:py-6">
        <a href="/" className="text-base font-extrabold md:col-span-6">
          Nexus
        </a>
        {/* PC：4つのリンクを並べる */}
        <nav aria-label="サイト内" className="hidden md:col-span-6 md:block">
          <ul className="flex justify-between gap-4 text-[13px]">
            {navItems.map((item) => (
              <li key={item.key}>
                <a
                  href={item.href}
                  aria-current={item.key === current ? 'page' : undefined}
                  className="border-b border-transparent pb-0.5 hover:border-rule aria-[current=page]:border-accent aria-[current=page]:text-accent"
                >
                  {item.label}
                </a>
              </li>
            ))}
          </ul>
        </nav>
        {/* スマホ：MENU ボタンで開く */}
        <button
          type="button"
          className="-mr-2 p-2 font-mono text-xs tracking-[0.08em] md:hidden"
          aria-expanded={menuOpen}
          aria-controls="mobile-menu"
          onClick={() => setMenuOpen(true)}
        >
          MENU
        </button>
      </header>
      {menuOpen && (
        <div id="mobile-menu" role="dialog" aria-modal="true" aria-label="メニュー" className="fixed inset-0 z-50 flex flex-col bg-bg md:hidden">
          <div className="flex h-14 shrink-0 items-center justify-between border-b border-rule px-5">
            <a href="/" className="text-base font-extrabold">
              Nexus
            </a>
            <button type="button" className="-mr-2 p-2 font-mono text-xs tracking-[0.08em]" onClick={() => setMenuOpen(false)} autoFocus>
              CLOSE
            </button>
          </div>
          <nav aria-label="サイト内" className="min-h-0 flex-1 overflow-y-auto overscroll-contain pb-[env(safe-area-inset-bottom)]">
            <ul>
              {navItems.map((item, i) => (
                <li key={item.key} className="border-b border-rule">
                  <a
                    href={item.href}
                    aria-current={item.key === current ? 'page' : undefined}
                    className="flex items-baseline gap-4 px-5 py-5 aria-[current=page]:text-accent"
                  >
                    <span className="font-mono text-[11px] tracking-[0.08em] text-label">0{i}</span>
                    <span className="text-[28px] font-black tracking-[-0.02em]">{item.label}</span>
                  </a>
                </li>
              ))}
            </ul>
          </nav>
        </div>
      )}
      <main className="border-t border-rule">{children}</main>
      <footer className={`mt-16 flex ${mobileBottomBar ? 'pb-28 md:pb-6' : ''} flex-col gap-2 border-t border-rule px-5 py-6 text-[13px] text-muted md:flex-row md:justify-between md:px-0`}>
        <span>Nexus — オープンキャンパスの iOS ガイド</span>
        <span className="font-mono text-[11px] tracking-[0.08em] text-label">© 2026 NEXUS</span>
      </footer>
      {mobileBottomBar && (
        <div className="fixed inset-x-0 bottom-0 z-40 border-t border-rule/15 bg-bg/90 px-5 pt-3 pb-[calc(12px+env(safe-area-inset-bottom))] backdrop-blur-xl md:hidden">
          {mobileBottomBar}
        </div>
      )}
    </div>
  );
}

/** 等幅の小さなラベル（例：OPEN CAMPUS GUIDE / iOS）。 */
export function Label({ children }: { children: ReactNode }) {
  return <p className="font-mono text-[11px] tracking-[0.08em] text-label">{children}</p>;
}

/** 下層ページの見出し。番号・英字ラベル・日本語の見出し・説明の順に並べる。 */
export function PageHeader({ index, label, title, lead }: { index: string; label: string; title: string; lead: string }) {
  return (
    <section className="grid gap-6 px-5 pt-10 pb-10 md:grid-cols-12 md:px-0 md:pt-12">
      <div className="md:col-span-8">
        <Label>
          {index} / {label}
        </Label>
        <h1 className="mt-5 text-5xl font-black leading-[1.1] tracking-[-0.03em] md:text-7xl">{title}</h1>
        <p className="mt-6 max-w-[460px] text-[15px] leading-[1.95] text-sub">{lead}</p>
      </div>
    </section>
  );
}
