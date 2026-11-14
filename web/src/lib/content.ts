/**
 * `web/content/` に手で書く Markdown を読む（#131、2026-11-14 利用者決定）。
 * 1件1ファイル。先頭の front matter（`key: value` の行）に日付と種類を書き、本文は最初の `## ` を見出しにする。
 * 本文で使える書き方は、段落・`- ` の箇条書き・`**太字**`・`[文字](URL)` だけ。ビルド時に読み込む。
 */

export type Block = { type: 'p'; text: string } | { type: 'ul'; items: string[] };

export type Entry = {
  slug: string;
  date: string;
  kind: string;
  title: string;
  blocks: Block[];
  meta: Record<string, string>;
};

export function parseEntry(slug: string, raw: string): Entry {
  const meta: Record<string, string> = {};
  let body = raw.replace(/\r\n/g, '\n');
  const fm = body.match(/^---\n([\s\S]*?)\n---\n?/);
  if (fm) {
    for (const line of fm[1].split('\n')) {
      const m = line.match(/^([\w-]+):\s*(.*)$/);
      if (m) meta[m[1]] = m[2].trim();
    }
    body = body.slice(fm[0].length);
  }
  let title = meta.title ?? '';
  const blocks: Block[] = [];
  for (const chunk of body.split(/\n{2,}/)) {
    const lines = chunk.split('\n').filter((l) => l.trim() !== '');
    if (lines.length === 0) continue;
    if (!title && lines[0].startsWith('## ')) {
      title = lines.shift()!.slice(3).trim();
      if (lines.length === 0) continue;
    }
    if (lines.every((l) => /^\s*-\s+/.test(l))) {
      blocks.push({ type: 'ul', items: lines.map((l) => l.replace(/^\s*-\s+/, '')) });
    } else {
      blocks.push({ type: 'p', text: lines.join('') });
    }
  }
  return { slug, date: meta.date ?? '', kind: meta.kind ?? '', title, blocks, meta };
}

function load(files: Record<string, string>): Entry[] {
  return Object.entries(files)
    .filter(([path]) => !path.split('/').pop()!.startsWith('_'))
    .map(([path, raw]) => parseEntry(path.split('/').pop()!.replace(/\.md$/, ''), raw))
    .sort((a, b) => b.date.localeCompare(a.date));
}

/** サーバー状況のお知らせ（メンテナンス・障害など）。新しい順。 */
export const notices = load(import.meta.glob('/content/notices/*.md', { query: '?raw', import: 'default', eager: true }));
