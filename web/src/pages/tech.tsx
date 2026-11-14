import { Layout, PageHeader } from '../components/Layout';
import { mount } from './mount';

function Page() {
  return (
    <Layout current="tech">
      <PageHeader index="03" label="NOTES" title="技術説明" lead="通信が途切れても地図を描ける理由など、Nexus を支える設計と技術を解説します。" />
      <section className="border-t border-rule px-5 pt-6 text-[15px] text-muted md:px-0">内容は準備中です。</section>
    </Layout>
  );
}

mount(<Page />);
