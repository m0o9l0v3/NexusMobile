/**
 * Nexus の公開サイト（#131）。
 *
 * アプリの告知・開発状況・サーバー状況・技術説明を掲載する予定。ページ構成と各項目の
 * データ源は #131 の「未決」を決めてから実装する。それまでは準備中であることだけを示し、
 * 状況を推測した値（稼働中など）は表示しない。参加者向けアプリ機能は iOS だけが持つ。
 */
const plannedSections = [
  { title: 'アプリの告知', body: 'オープンキャンパス向け iOS アプリ「Nexus」のご案内' },
  { title: '開発状況', body: '機能ごとの開発の進み具合' },
  { title: 'サーバー状況', body: '公開サービスの稼働状況やメンテナンスのお知らせ' },
  { title: '技術説明', body: 'Nexus を支える設計と技術の解説' },
];

export default function App() {
  return (
    <main className="min-h-screen bg-[linear-gradient(180deg,var(--sky-0),var(--sky-1))] px-4 py-10 text-[var(--text)]">
      <div className="mx-auto flex max-w-2xl flex-col gap-5">
        <header className="flex flex-col gap-2">
          <h1 className="text-3xl font-bold">Nexus</h1>
          <p className="text-base text-[var(--muted-foreground)]">このサイトは準備中です。</p>
        </header>

        <section
          aria-labelledby="planned-heading"
          className="rounded-[20px] bg-[var(--surface)] p-5 shadow-[var(--elev-2)]"
        >
          <h2 id="planned-heading" className="text-lg font-semibold">
            掲載予定の内容
          </h2>
          <ul className="mt-4 flex flex-col gap-4">
            {plannedSections.map((section) => (
              <li key={section.title} className="flex flex-col gap-1">
                <span className="font-medium">{section.title}</span>
                <span className="text-sm text-[var(--muted-foreground)]">{section.body}</span>
              </li>
            ))}
          </ul>
        </section>
      </div>
    </main>
  );
}
