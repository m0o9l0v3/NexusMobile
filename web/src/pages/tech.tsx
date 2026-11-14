/**
 * 技術説明（#131）。公式の開発者ドキュメント（リファレンス）風に、1ページにまとめる（2026-11-14 利用者決定）。
 * 左に項目の一覧（読んでいる節を示す）、本文にコード例や表を置く。量が増えたら節ごとのページに分ける。
 *
 * 載せないもの（2026-10-25 決定）：ホスト名・IP・ポート・サーバーソフトの版、DB のロール・権限、秘密情報の置き場所、
 * 認証の細部、rate limit の値、未決事項・Issue 番号・作業経緯。
 */
import { useEffect, useState, type ReactNode } from 'react';
import { Label, Layout, PageHeader } from '../components/Layout';
import { mount } from './mount';

const UPDATED = '2026-11-14';

type TocItem = { id: string; title: string; children?: { id: string; title: string }[] };

const toc: TocItem[] = [
  { id: 'overview', title: '概要' },
  { id: 'architecture', title: '全体の構成', children: [{ id: 'technologies', title: '採用した技術' }] },
  {
    id: 'data',
    title: 'データの形',
    children: [
      { id: 'coordinates', title: '座標系' },
      { id: 'identifiers', title: 'ID の付け方' },
    ],
  },
  {
    id: 'delivery',
    title: 'データの配信',
    children: [
      { id: 'conditional-get', title: '更新の確かめ方' },
      { id: 'integrity', title: '検証と切り替え' },
    ],
  },
  { id: 'offline', title: '通信が途切れたとき' },
];

const allIds = toc.flatMap((t) => [t.id, ...(t.children ?? []).map((c) => c.id)]);

/** いま読んでいる節の id。画面の上 1/4 を越えた最後の見出しを選ぶ。 */
function useActiveSection() {
  const [active, setActive] = useState(allIds[0]);
  useEffect(() => {
    const onScroll = () => {
      const line = window.innerHeight * 0.25;
      let current = allIds[0];
      for (const id of allIds) {
        const el = document.getElementById(id);
        if (el && el.getBoundingClientRect().top <= line) current = id;
      }
      setActive(current);
    };
    onScroll();
    window.addEventListener('scroll', onScroll, { passive: true });
    return () => window.removeEventListener('scroll', onScroll);
  }, []);
  return active;
}

function TocList({ active, onNavigate }: { active?: string; onNavigate?: () => void }) {
  const link = (id: string, title: string, nested: boolean) => (
    <a
      href={`#${id}`}
      onClick={onNavigate}
      aria-current={active === id ? 'location' : undefined}
      className={`-ml-px block border-l py-1.5 text-[13px] leading-snug ${nested ? 'pl-6' : 'pl-3.5'} ${
        active === id ? 'border-accent font-bold text-accent' : 'border-transparent text-sub hover:text-fg'
      }`}
    >
      {title}
    </a>
  );
  return (
    <ul className="border-l border-rule/15">
      {toc.map((t) => (
        <li key={t.id}>
          {link(t.id, t.title, false)}
          {t.children && (
            <ul>
              {t.children.map((c) => (
                <li key={c.id}>{link(c.id, c.title, true)}</li>
              ))}
            </ul>
          )}
        </li>
      ))}
    </ul>
  );
}

function H2({ id, children }: { id: string; children: ReactNode }) {
  return (
    <h2 id={id} className="scroll-mt-6 border-t border-rule/15 pt-10 text-[26px] font-extrabold tracking-[-0.02em] first:border-t-0 first:pt-0">
      <a href={`#${id}`} className="hover:text-accent">
        {children}
      </a>
    </h2>
  );
}

function H3({ id, children }: { id: string; children: ReactNode }) {
  return (
    <h3 id={id} className="mt-9 scroll-mt-6 text-lg font-bold">
      <a href={`#${id}`} className="hover:text-accent">
        {children}
      </a>
    </h3>
  );
}

function P({ children }: { children: ReactNode }) {
  return <p className="mt-4 text-[15px] leading-[1.95] text-sub">{children}</p>;
}

function C({ children }: { children: ReactNode }) {
  return <code className="rounded-[3px] bg-panel px-1.5 py-px font-mono text-[0.86em] text-fg">{children}</code>;
}

function Code({ caption, children }: { caption?: string; children: string }) {
  return (
    <figure className="mt-5">
      <pre className="overflow-x-auto border border-rule/15 bg-panel px-4 py-4 font-mono text-[12.5px] leading-[1.75] text-fg">{children}</pre>
      {caption && <figcaption className="mt-2 font-mono text-[11px] tracking-[0.06em] text-label">{caption}</figcaption>}
    </figure>
  );
}

function Table({ head, rows }: { head: string[]; rows: ReactNode[][] }) {
  return (
    <div className="mt-5 overflow-x-auto">
      <table className="w-full min-w-[520px] border-collapse text-[13.5px]">
        <thead>
          <tr>
            {head.map((h) => (
              <th key={h} className="border-b border-rule py-2 pr-4 text-left font-bold">
                {h}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {rows.map((r, i) => (
            <tr key={i}>
              {r.map((cell, j) => (
                <td key={j} className="border-b border-rule/15 py-2.5 pr-4 align-top leading-[1.7] text-sub">
                  {cell}
                </td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

/** 決まりごと（〜しなければならない）を目立たせる枠。 */
function Rule({ children }: { children: ReactNode }) {
  return <p className="mt-5 border-l-[3px] border-accent bg-panel px-4 py-3 text-sm leading-[1.85] text-fg">{children}</p>;
}

function FlowDiagram() {
  const nodes = [
    ['01 STUDIO', 'Studio', '地点・地図・イベントを編集し、公開する'],
    ['02 DELIVERY', '配信用の版', '公開のたびに新しい bundle を作り、変えずに残す'],
    ['03 PUBLIC API', '公開 API', '最新の bundle を読み取って返すだけ'],
    ['04 iOS', 'アプリ', '検証してから保存し、まとめて切り替える'],
  ];
  return (
    <figure className="mt-6">
      <ol className="grid gap-2 md:grid-cols-[1fr_auto_1fr_auto_1fr_auto_1fr] md:items-stretch md:gap-0">
        {nodes.map(([label, title, body], i) => (
          <li key={label} className="contents">
            <div className="border border-rule px-4 py-3.5">
              <span className="block font-mono text-[10.5px] tracking-[0.08em] text-label">{label}</span>
              <b className="mt-1.5 block text-[15px]">{title}</b>
              <span className="mt-1 block text-xs leading-[1.6] text-muted">{body}</span>
            </div>
            {i < nodes.length - 1 && (
              <span aria-hidden="true" className="self-center px-2 text-center font-mono text-[13px] text-accent">
                <span className="md:hidden">↓</span>
                <span className="hidden md:inline">→</span>
              </span>
            )}
          </li>
        ))}
      </ol>
      <figcaption className="mt-2 font-mono text-[11px] tracking-[0.06em] text-label">FIG.1 — 公開データがアプリに届くまで</figcaption>
    </figure>
  );
}

function Body() {
  return (
    <div className="flex flex-col gap-0">
      <section>
        <H2 id="overview">概要</H2>
        <P>
          Nexus は、オープンキャンパスの来場者が構内で迷わないための iOS アプリです。建物の場所・地点・イベントを地図に示し、学校生活などの案内を読めるようにします。
        </P>
        <P>
          会場は人が多く、通信が不安定になりがちです。そこで Nexus は「必要なデータを前もって端末に保存し、通信が途切れても表示を続ける」ことを設計の中心に置いています。このページでは、そのための構成とデータの扱いを説明します。
        </P>
      </section>

      <section className="mt-12">
        <H2 id="architecture">全体の構成</H2>
        <P>
          公開するデータ（地点・地図・経路・イベント）は、編集用の Studio で作り、公開の操作をしたときにだけ配信用の版になります。アプリは公開 API から版をまるごと受け取り、端末に保存して使います。
        </P>
        <FlowDiagram />
        <P>
          公開 API は読み取り専用で、公開済みのデータを返すだけです。データの編集や「前の状態へ戻す」操作は Studio だけが行います。アプリに利用者の登録やログインはなく、来場者の個人情報を集めません。
        </P>
        <H3 id="technologies">採用した技術</H3>
        <Table
          head={['部分', '技術', '理由']}
          rows={[
            ['iOS アプリ', 'SwiftUI、MapKit', 'OS 標準の部品だけで作り、外部の地図 SDK を足さない。依存やライセンスの管理を増やさないため'],
            ['公開 API', 'ASP.NET Core、Entity Framework Core', '型のある言語で API の契約（OpenAPI）とテストを保ちやすいため'],
            ['データベース', 'PostgreSQL', '編集用と配信用のデータを同じデータベースの別の領域に置き、公開を1つのトランザクションで済ませるため'],
            ['地図データ', 'GeoJSON（RFC 7946）', '標準の形式で、MapKit に緯度経度をそのまま渡せるため'],
            ['公開サイト', 'React、Vite（静的ファイル）', 'サーバーの処理を持たず、配信するだけで済むため'],
          ]}
        />
      </section>

      <section className="mt-12">
        <H2 id="data">データの形</H2>
        <P>
          地点・地図・経路グラフは、1つの JSON ドキュメント（<strong>bundle</strong>）にまとめます。形は JSON Schema で定め、アプリは受け取った bundle がその形に合うかを確かめてから使います。
        </P>
        <H3 id="coordinates">座標系</H3>
        <P>
          屋外の座標はすべて WGS 84（OGC CRS84）の2次元で、GeoJSON の決まりどおり <C>[経度, 緯度]</C> の順に並べます。単位は10進の度で、小数6桁に丸めます。高さは持ちません。
        </P>
        <Code caption="例 — 地点を表す GeoJSON の Feature（座標は説明用の値）">{`{
  "type": "Feature",
  "id": "mb",
  "geometry": { "type": "Point", "coordinates": [139.000000, 35.000000] },
  "properties": { "name": "教室棟" }
}`}</Code>
        <P>
          建物の中のフロア図は、フロアごとのメートル単位の平面座標で作り、公開するときに WGS 84 へ変換します（2次元の相似変換）。同じ入力からは、いつも同じ座標が出るようにしています。
        </P>
        <H3 id="identifiers">ID の付け方</H3>
        <P>
          建物・フロア・入口・部屋などには、短く読める ID を付けます。すべて ASCII の小文字と <C>_</C> だけで書き、番号は <C>001</C> から始めます。
        </P>
        <Table
          head={['対象', '形式', '例']}
          rows={[
            ['建物', <C key="a">{'{building}'}</C>, <C key="b">mb</C>],
            ['フロア', <C key="a">{'{building}_{floor}'}</C>, <C key="b">mb_1f</C>],
            ['正式な入口', <C key="a">{'{building}_ent_{seq}'}</C>, <C key="b">mb_ent_001</C>],
            ['部屋', <C key="a">{'{floor}_{type}_{seq}'}</C>, <C key="b">mb_2f_cl_001</C>],
            ['屋外の経路の点', <C key="a">{'campus_n_{seq}'}</C>, <C key="b">campus_n_001</C>],
          ]}
        />
        <Rule>
          一度公開した ID は、別のものに使い回しません。名前が変わったときは新しい ID を発行し、古い ID から新しい ID への対応を台帳に追記します。アプリは bundle の外から来た ID（イベントの会場など）を、この対応で1段だけ引き直します。
        </Rule>
        <P>
          建物の ID 自体に <C>_</C> を含むもの（例：<C>ctc_main</C>）があるため、ID を <C>_</C> で区切って親を推測することはしません。親子の関係はデータの中の参照で持ちます。
        </P>
      </section>

      <section className="mt-12">
        <H2 id="delivery">データの配信</H2>
        <P>
          bundle は1つの版として配信します。地点と地図を別々に取りに行かないので、版の異なるデータが端末の中で混ざることがありません。
        </P>
        <P>
          公開のたびに新しい bundle を作り、作った bundle は書き換えません。版の番号（<C>bundle_version</C>）は増えるだけです。誤って公開した内容を元に戻すときも、「元の内容を持つ新しい版」として公開します。
        </P>
        <H3 id="conditional-get">更新の確かめ方</H3>
        <P>
          アプリは HTTP の条件付きリクエスト（RFC 9110）で更新を確かめます。版が変わっていなければ、本体は送られません。確かめるのは起動時と、アプリが前面に戻ってから一定の間隔が空いたときだけです。
        </P>
        <Code caption="例 — 版が変わっていないとき">{`GET /api/v2/bundle
If-None-Match: "sha256-…"

HTTP/1.1 304 Not Modified
ETag: "sha256-…"
Nexus-Bundle-Version: 42`}</Code>
        <H3 id="integrity">検証と切り替え</H3>
        <Table
          head={['ヘッダー', '役割', 'アプリの扱い']}
          rows={[
            [<C key="h">ETag</C>, '条件付きリクエストの鍵', <>値を解釈せずに保存し、次の <C>If-None-Match</C> にそのまま送る</>],
            [<C key="h">Nexus-Bundle-Sha256</C>, '中身の照合', '受け取った本体（展開後）の SHA-256 と比べる'],
            [<C key="h">Nexus-Bundle-Length</C>, '大きさの照合', '受け取ったバイト数と比べる'],
            [<C key="h">Nexus-Bundle-Version</C>, '版の番号', '保存している版より小さければ使わない'],
          ]}
        />
        <P>
          照合に <C>ETag</C> を使わないのは、途中の中継が圧縮のときに <C>ETag</C> の値を書き換えることがあるためです。中身の照合は専用のヘッダーで行い、中継はこれを変えません。
        </P>
        <Rule>
          アプリは、照合に失敗した bundle や、保存している版より古い bundle を採用しません。その場合は、保存している版の表示を続けます。新しい版は一時ファイルに書き、全体を読み込めてから一度に置き換え、前の版を1つ残します。
        </Rule>
      </section>

      <section className="mt-12">
        <H2 id="offline">通信が途切れたとき</H2>
        <P>
          地図は MapKit で表示しますが、建物の形・地点のピン・地点名は、Apple の地図の模様ではなく、保存した bundle の座標からアプリが描きます。通信が途切れると Apple の地図の模様（道路や川など）は出なくなりますが、構内の建物と地点はそのまま表示されます。
        </P>
        <Table
          head={['表示するもの', '通信が途切れたとき']}
          rows={[
            ['建物の形・地点のピン・地点名（アプリが描く）', '表示される'],
            ['方位・縮尺', '表示される'],
            ['Apple の地図の模様（道路・川など）', '表示されないことがある（以前に表示した分が残っていれば出る）'],
          ]}
        />
        <P>
          MapKit が描く地点名は、通信が途切れると消えることを確かめたため、地点名はアプリ側で描いています。イベントや案内の情報も bundle やアプリの中に持ち、通信がなくても読めるようにしています。
        </P>
      </section>
    </div>
  );
}

function Page() {
  const active = useActiveSection();
  return (
    <Layout current="tech">
      <PageHeader index="03" label="NOTES" title="技術説明" lead="通信が途切れても地図を描ける理由など、Nexus を支える設計と技術を解説します。" />
      <div className="border-t border-rule px-5 pt-8 pb-4 md:grid md:grid-cols-12 md:gap-6 md:px-0 md:pt-10">
        {/* スマホ：目次は開閉できる一覧にする */}
        <details className="mb-8 border border-rule/15 md:hidden">
          <summary className="cursor-pointer px-4 py-3 font-mono text-[11px] tracking-[0.08em] text-label">CONTENTS — 目次</summary>
          <div className="px-4 pb-4">
            <TocList />
          </div>
        </details>
        {/* PC：左の一覧は読み進めても残り、読んでいる節を示す */}
        <aside className="hidden md:col-span-3 md:block">
          <nav aria-label="このページの項目" className="sticky top-6">
            <Label>NEXUS TECHNICAL NOTES</Label>
            <div className="mt-4">
              <TocList active={active} />
            </div>
            <p className="mt-8 font-mono text-[11px] tracking-[0.08em] text-label">
              UPDATED <time dateTime={UPDATED}>{UPDATED.replace(/-/g, '.')}</time>
            </p>
          </nav>
        </aside>
        <article className="min-w-0 md:col-span-9 md:max-w-[760px] md:pl-6">
          <Body />
          <p className="mt-12 font-mono text-[11px] tracking-[0.08em] text-label md:hidden">
            UPDATED <time dateTime={UPDATED}>{UPDATED.replace(/-/g, '.')}</time>
          </p>
        </article>
      </div>
    </Layout>
  );
}

mount(<Page />);
