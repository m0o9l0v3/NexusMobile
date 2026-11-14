/**
 * 開発状況（#131）。機能ごとの一覧に「完成・作業中・予定」の印を付ける（2026-11-14 利用者決定）。
 * 中身は web/content/development/*.md に手で書く。Issue 番号や内部の事情は書かない。
 */
import { Label, Layout, PageHeader } from '../components/Layout';
import { Prose } from '../components/Prose';
import { features } from '../lib/content';
import { mount } from './mount';

const statusView: Record<string, { label: string; className: string }> = {
  done: { label: '完成', className: 'text-ok' },
  wip: { label: '作業中', className: 'text-accent' },
  planned: { label: '予定', className: 'text-label' },
};

function formatDate(iso: string) {
  return iso.replace(/-/g, '.');
}

function Page() {
  const updated = features.map((f) => f.meta.updated ?? '').sort().pop();
  return (
    <Layout current="development">
      <PageHeader index="01" label="DEVELOPMENT" title="開発状況" lead="Nexus の開発の進み具合を、機能ごとにお知らせします。" />
      <section aria-labelledby="features-heading" className="border-t border-rule px-5 py-8 md:grid md:grid-cols-12 md:gap-6 md:px-0">
        <div className="md:col-span-4">
          <Label>FEATURES</Label>
          <h2 id="features-heading" className="mt-2 text-lg font-bold">
            機能ごとの進み具合
          </h2>
          {updated && (
            <p className="mt-3 font-mono text-[11px] tracking-[0.08em] text-label">
              UPDATED <time dateTime={updated}>{formatDate(updated)}</time>
            </p>
          )}
        </div>
        <ol className="mt-4 md:col-span-8 md:mt-0">
          {features.map((f, i) => {
            const st = statusView[f.meta.status ?? ''] ?? { label: f.meta.status ?? '', className: 'text-label' };
            return (
              <li key={f.slug} className="grid grid-cols-[28px_1fr_auto] items-baseline gap-x-3 border-b border-rule/15 py-[18px] md:grid-cols-[40px_1fr_auto] md:gap-x-4">
                <span className="font-mono text-[11px] tracking-[0.08em] text-label">{String(i + 1).padStart(2, '0')}</span>
                <div>
                  <h3 className="text-base font-bold md:text-[17px]">{f.title}</h3>
                  <div className="mt-1 [&_p]:text-[13px] [&_p]:leading-[1.7] [&_p]:text-muted">
                    <Prose blocks={f.blocks} />
                  </div>
                </div>
                <span className={`whitespace-nowrap rounded-full border border-current px-2 py-0.5 font-mono text-[11px] tracking-[0.06em] ${st.className}`}>
                  ● {st.label}
                </span>
              </li>
            );
          })}
        </ol>
      </section>
    </Layout>
  );
}

mount(<Page />);
