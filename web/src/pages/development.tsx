import { Layout, PageHeader } from '../components/Layout';
import { mount } from './mount';

function Page() {
  return (
    <Layout current="development">
      <PageHeader index="01" label="DEVELOPMENT" title="開発状況" lead="Nexus の開発の進み具合を、機能ごとにお知らせします。" />
      <section className="border-t border-rule px-5 pt-6 text-[15px] text-muted md:px-0">内容は準備中です。</section>
    </Layout>
  );
}

mount(<Page />);
