/**
 * サーバー状況（#131）。ブラウザから `/health` に届くか（応答あり／応答なし）と、手で書くお知らせだけを出す。
 * 版・構成・ホスト名・応答時間など、攻撃の手掛かりになる情報は出さない。
 */
import { Label, Layout, PageHeader } from '../components/Layout';
import { Prose } from '../components/Prose';
import { notices } from '../lib/content';
import { useHealth } from '../lib/health';
import { mount } from './mount';

const kindLabel: Record<string, string> = {
  maintenance: 'MAINTENANCE / メンテナンス',
  incident: 'INCIDENT / 障害',
  info: 'INFO / お知らせ',
};

function formatDate(iso: string) {
  const [y, m, d] = iso.split('-');
  return y && m && d ? `${y}.${m}.${d}` : iso;
}

function HealthPanel() {
  const { state, checkedAt, recheck } = useHealth();
  const text = state === 'checking' ? '確認中' : state === 'ok' ? '応答あり' : '応答なし';
  const dot = state === 'checking' ? 'bg-label animate-pulse' : state === 'ok' ? 'bg-ok' : 'bg-ng';
  return (
    <section aria-labelledby="health-heading" className="border-t border-rule px-5 py-8 md:grid md:grid-cols-12 md:gap-6 md:px-0">
      <div className="md:col-span-4">
        <Label>SERVER</Label>
        <h2 id="health-heading" className="mt-2 text-lg font-bold">
          サーバーの応答
        </h2>
      </div>
      <div className="mt-5 md:col-span-8 md:mt-0">
        <p className="flex items-center gap-3 text-[40px] font-black leading-none tracking-[-0.02em] md:text-[56px]" aria-live="polite">
          <span aria-hidden="true" className={`inline-block size-4 rounded-full md:size-5 ${dot}`} />
          {text}
        </p>
        <div className="mt-4 flex flex-wrap items-center gap-x-5 gap-y-2 text-[13px] text-muted">
          <span className="font-mono text-[11px] tracking-[0.08em] text-label">
            {checkedAt ? `CHECKED ${checkedAt.toLocaleTimeString('ja-JP', { hour: '2-digit', minute: '2-digit' })}` : 'CHECKING…'}
          </span>
          <button type="button" onClick={recheck} disabled={state === 'checking'} className="underline underline-offset-2 disabled:opacity-40">
            もう一度確かめる
          </button>
        </div>
        <p className="mt-5 max-w-[520px] text-[13px] leading-[1.8] text-muted">
          このページを開いたブラウザから、アプリが使うサーバーに届くかを確かめています。「応答なし」のときは、お使いの通信環境が原因のこともあります。
        </p>
      </div>
    </section>
  );
}

function Notices() {
  return (
    <section aria-labelledby="notices-heading" className="border-t border-rule px-5 py-8 md:grid md:grid-cols-12 md:gap-6 md:px-0">
      <div className="md:col-span-4">
        <Label>NOTICES</Label>
        <h2 id="notices-heading" className="mt-2 text-lg font-bold">
          お知らせ
        </h2>
      </div>
      <div className="mt-5 md:col-span-8 md:mt-0">
        {notices.length === 0 ? (
          <p className="text-sm text-muted">現在、メンテナンスや障害のお知らせはありません。</p>
        ) : (
          <ol className="flex flex-col">
            {notices.map((n) => (
              <li key={n.slug} className="border-b border-rule/20 py-5 first:pt-0 last:border-b-0">
                <p className="font-mono text-[11px] tracking-[0.08em] text-label">
                  {formatDate(n.date)} — <span className={n.kind === 'incident' ? 'text-ng' : 'text-accent'}>{kindLabel[n.kind] ?? n.kind.toUpperCase()}</span>
                </p>
                <h3 className="mt-2 mb-3 text-lg font-bold md:text-xl">{n.title}</h3>
                <Prose blocks={n.blocks} />
              </li>
            ))}
          </ol>
        )}
      </div>
    </section>
  );
}

function Page() {
  return (
    <Layout current="status">
      <PageHeader index="02" label="STATUS" title="サーバー状況" lead="サーバーが応答しているかと、メンテナンスや障害のお知らせです。" />
      <HealthPanel />
      <Notices />
    </Layout>
  );
}

mount(<Page />);
