import { Fragment, type ReactNode } from 'react';
import type { Block } from '../lib/content';

/** `**太字**` と `[文字](URL)` だけを解釈する。それ以外はそのまま文字として出す。 */
function inline(text: string): ReactNode[] {
  const out: ReactNode[] = [];
  const re = /\*\*(.+?)\*\*|\[(.+?)\]\((https?:\/\/[^\s)]+)\)/g;
  let last = 0;
  let m: RegExpExecArray | null;
  while ((m = re.exec(text))) {
    if (m.index > last) out.push(text.slice(last, m.index));
    if (m[1]) out.push(<strong key={m.index}>{m[1]}</strong>);
    else out.push(<a key={m.index} href={m[3]} className="text-accent underline underline-offset-2">{m[2]}</a>);
    last = re.lastIndex;
  }
  if (last < text.length) out.push(text.slice(last));
  return out;
}

export function Prose({ blocks }: { blocks: Block[] }) {
  return (
    <div className="flex flex-col gap-3 text-sm leading-[1.9] text-sub md:text-[15px]">
      {blocks.map((b, i) => (
        <Fragment key={i}>
          {b.type === 'p' ? (
            <p>{inline(b.text)}</p>
          ) : (
            <ul className="flex flex-col gap-1 pl-4">
              {b.items.map((it, j) => (
                <li key={j} className="list-disc marker:text-label">{inline(it)}</li>
              ))}
            </ul>
          )}
        </Fragment>
      ))}
    </div>
  );
}
