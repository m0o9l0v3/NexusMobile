import { useEffect, useRef, useState } from 'react';
import { toast } from 'sonner';
import searchBackIcon from '@/assets/map/search-back.svg';
import searchMicIcon from '@/assets/map/search-mic.svg';

type MapSearchOverlayProps = {
  isOpen: boolean;
  onClose: () => void;
};

export function MapSearchOverlay({ isOpen, onClose }: MapSearchOverlayProps) {
  const [query, setQuery] = useState('');
  const dialogRef = useRef<HTMLDivElement>(null);
  const inputRef = useRef<HTMLInputElement>(null);

  const closeSearch = () => {
    setQuery('');
    onClose();
  };

  useEffect(() => {
    if (!isOpen) return;

    setQuery('');
    const focusFrame = window.requestAnimationFrame(() => inputRef.current?.focus());

    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        event.preventDefault();
        closeSearch();
        return;
      }

      if (event.key !== 'Tab') return;

      const focusable = dialogRef.current?.querySelectorAll<HTMLElement>(
        'button:not([disabled]), input:not([disabled])',
      );
      if (!focusable?.length) return;

      const first = focusable[0];
      const last = focusable[focusable.length - 1];

      if (event.shiftKey && document.activeElement === first) {
        event.preventDefault();
        last.focus();
      } else if (!event.shiftKey && document.activeElement === last) {
        event.preventDefault();
        first.focus();
      }
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => {
      window.cancelAnimationFrame(focusFrame);
      window.removeEventListener('keydown', handleKeyDown);
    };
  }, [isOpen]);

  if (!isOpen) return null;

  return (
    <div
      ref={dialogRef}
      className="fixed inset-0 z-[100] flex flex-col items-center bg-white"
      role="dialog"
      aria-modal="true"
      aria-label="校内マップ検索"
      style={{ paddingTop: 'calc(env(safe-area-inset-top, 0px) + 26px)' }}
    >
      <form
        className="flex h-[55px] w-[calc(100%_-_28px)] max-w-[365px] shrink-0 items-center rounded-[30px] bg-[#f4f6f7]"
        onSubmit={(event) => event.preventDefault()}
        role="search"
      >
        <button
          type="button"
          onClick={closeSearch}
          className="flex h-[55px] w-11 shrink-0 items-center justify-center rounded-l-[30px]"
          aria-label="マップへ戻る"
        >
          <img src={searchBackIcon} alt="" className="h-6 w-6" />
        </button>

        <input
          ref={inputRef}
          type="search"
          value={query}
          onChange={(event) => setQuery(event.target.value)}
          placeholder="検索"
          inputMode="search"
          enterKeyHint="search"
          autoComplete="off"
          className="h-full min-w-0 flex-1 bg-transparent px-2 text-[17px] font-semibold leading-[22px] text-[#1c1c1e] outline-none placeholder:text-[#797979]"
          style={{
            fontFamily: '-apple-system, BlinkMacSystemFont, "Noto Sans JP", "Inter", sans-serif',
          }}
          aria-label="施設や経路を検索"
        />

        <button
          type="button"
          onClick={() => toast('音声入力は準備中です')}
          className="flex h-[55px] w-11 shrink-0 items-center justify-center rounded-r-[30px]"
          aria-label="音声入力（準備中）"
        >
          <img src={searchMicIcon} alt="" className="h-6 w-6" />
        </button>
      </form>

      <div className="w-full flex-1" aria-live="polite" />
    </div>
  );
}
