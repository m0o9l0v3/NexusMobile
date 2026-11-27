/**
 * プライバシーポリシー（App Store 申請および公開サイト用）。
 * 公開サイトのデザインルール（スイス風ミニマル・12列グリッド・罫線）に合わせ、
 * 内部事情や秘密情報は載せない。
 */
import type { ReactNode } from 'react';
import { Label, Layout, PageHeader } from '../components/Layout';
import { mount } from './mount';

const UPDATED = '2026-11-28';

function Section({
  id,
  label,
  title,
  meta,
  children,
}: {
  id: string;
  label: string;
  title: string;
  meta?: ReactNode;
  children: ReactNode;
}) {
  return (
    <section aria-labelledby={id} className="border-t border-rule px-5 py-8 md:grid md:grid-cols-12 md:gap-6 md:px-0">
      <div className="md:col-span-4">
        <Label>{label}</Label>
        <h2 id={id} className="mt-2 text-lg font-bold">
          {title}
        </h2>
        {meta}
      </div>
      <div className="mt-4 space-y-3 text-[15px] leading-[1.9] text-sub md:col-span-8 md:mt-0">{children}</div>
    </section>
  );
}

function Page() {
  return (
    <Layout current="privacy">
      <PageHeader
        index="04"
        label="PRIVACY"
        title="プライバシーポリシー"
        lead="Nexus（iOS アプリ）および公開サイト（www.nexus-app.jp）における情報の取り扱い方針です。"
      />

      <Section
        id="policy"
        label="01 / POLICY"
        title="基本方針"
        meta={
          <p className="mt-3 font-mono text-[11px] tracking-[0.08em] text-label">
            UPDATED <time dateTime={UPDATED}>{UPDATED.replace(/-/g, '.')}</time>
          </p>
        }
      >
        <p>
          Nexus（iOS アプリ）は、アカウント登録やログインを必要とせず、氏名・メールアドレス・電話番号・学校名などの個人情報を収集・保持しません。
        </p>
        <p>第三者による広告配信 SDK や行動トラッキングも組み込んでいません。</p>
      </Section>

      <Section id="location" label="02 / LOCATION" title="位置情報の取り扱い">
        <p>
          構内地図での現在地表示および経路案内の出発地設定のため、利用者が許可した場合に限り、アプリを使用している間だけ端末の位置情報を取得します。
        </p>
        <p>
          取得した位置情報は端末内のみで処理され、Nexus のサーバーや外部へ送信・保存することはありません。位置情報の利用を許可しない場合でも、手動で出発地を選んで構内の経路案内を利用できます。
        </p>
      </Section>

      <Section id="storage" label="03 / STORAGE" title="端末内に保存されるデータ">
        <p>
          電波が届きにくい場所やオフライン環境でも地図・施設情報・イベント案内を閲覧できるよう、サーバーから取得した公開データ（最終同期から 7 日間有効）を端末内に保存します。
        </p>
        <p>
          アプリ内の検索履歴や表示状態も端末内のみで管理され、外部へ送信しません。アプリを端末から削除すると、保存されたデータはすべて消去されます。
        </p>
      </Section>

      <Section id="network" label="04 / NETWORK" title="外部サービスと通信">
        <ul className="list-disc space-y-2 pl-5">
          <li>背景地図の描画には Apple MapKit を利用します（Apple のプライバシーポリシーが適用されます）。</li>
          <li>最新の公開データ取得のため HTTPS 通信を行いますが、個人を特定する識別子や行動ログは送信しません。</li>
          <li>案内記事内の外部サイトや電話リンクは、利用者が明示的にタップした場合のみブラウザや電話アプリを開きます。</li>
        </ul>
      </Section>

      <Section id="website" label="05 / WEBSITE" title="公開サイトについて">
        <p>公開サイト（www.nexus-app.jp）では、利用者の追跡を目的とした Cookie やアクセス解析ツールを使用しません。</p>
        <p>
          「サーバー状況」ページでは、アプリが利用する公開サーバーへの接続可否のみをブラウザから確認し、個人情報を送信しません。
        </p>
      </Section>

      <Section id="contact" label="06 / CONTACT" title="改定とお問い合わせ">
        <p>法令やアプリ仕様の変更に伴い本ポリシーを改定する場合は、本ページにて更新日とともに公開します。</p>
        <p>
          アプリに関するご案内は{' '}
          <a href="/" className="underline underline-offset-4 hover:text-accent">
            Nexus 公式サイト
          </a>
          、オープンキャンパス全般のお問い合わせは{' '}
          <a
            href="https://www.jaa-tech.jp/contact-information/"
            target="_blank"
            rel="noopener noreferrer"
            className="underline underline-offset-4 hover:text-accent"
          >
            日本航空大学校 公式お問い合わせ一覧
          </a>
          をご確認ください。
        </p>
      </Section>
    </Layout>
  );
}

mount(<Page />);
