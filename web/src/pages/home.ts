import { createButton } from "../components/button";
import { createCard } from "../components/card";
import { createTicketCard } from "../components/ticketCard";
import { showToast } from "../components/toast";
import { getTodayEvents } from "../lib/api";
import { logEvent } from "../lib/logger";
import type { EventItem } from "../types";

type HomeOptions = {
  onCodeSubmit: (code: string) => void;
  onNavigate: (path: string) => void;
  onRequestQr: () => void;
};

const renderEvents = (wrapper: HTMLElement, events: EventItem[]) => {
  wrapper.innerHTML = "";
  if (!events.length) {
    wrapper.textContent = "本日のイベント情報はまだありません。";
    return;
  }
  const list = document.createElement("div");
  list.className = "grid";
  events.forEach((evt) => {
    const card = createCard();
    card.classList.add("event-card");
    card.innerHTML = `
      <div class="row space-between">
        <div>
          <div class="muted tabular">${evt.start} - ${evt.end}</div>
          <div class="event-card__title">${evt.title}</div>
          <div class="muted">${evt.location}</div>
        </div>
        <div class="chip">${evt.spotCode ?? "SPOT"}</div>
      </div>
    `;
    list.appendChild(card);
  });
  wrapper.appendChild(list);
};

export const renderHome = (options: HomeOptions): HTMLElement => {
  const page = document.createElement("div");
  page.className = "grid";

  const heroCard = createCard();
  heroCard.classList.add("home-hero");
  heroCard.innerHTML = `
    <div>
      <p class="muted">旅のようなキャンパス体験を、軽やかに。</p>
      <h1 class="hero-title">Nexus Pass</h1>
      <p class="muted">QR/コード入力か現在地でスポットを開けます。カメラ拒否・電波が不安定でも手入力・一覧で代替できます。</p>
    </div>
  `;

  const form = document.createElement("form");
  form.className = "search-card surface glass";
  const input = document.createElement("input");
  input.type = "text";
  input.name = "code";
  input.placeholder = "例: NXS01 / OC22";
  input.required = true;
  input.className = "search-input tabular";

  const submitBtn = createButton({ label: "開く", variant: "primary" });
  submitBtn.type = "submit";

  const qrBtn = createButton({
    label: "QRスキャン",
    variant: "secondary",
    onClick: () => {
      options.onRequestQr();
      logEvent({ type: "qr_scan" });
    },
  });

  form.append(input, submitBtn, qrBtn);
  form.addEventListener("submit", (e) => {
    e.preventDefault();
    const code = input.value.trim();
    if (!code) return;
    options.onCodeSubmit(code);
    showToast({ message: `${code} を開いています`, tone: "info" });
  });

  const quickRow = document.createElement("div");
  quickRow.className = "row quick-row";
  quickRow.append(
    createButton({
      label: "現在地から探す",
      variant: "secondary",
      onClick: () => options.onNavigate("/nearby"),
    }),
    createButton({
      label: "イベント一覧",
      variant: "ghost",
      onClick: () => options.onNavigate("/events"),
    }),
  );

  const ticketWrap = document.createElement("div");
  ticketWrap.className = "grid";
  const ticketTitle = document.createElement("div");
  ticketTitle.className = "section-title";
  ticketTitle.textContent = "本日のスケジュール";
  const ticketCard = createTicketCard({
    code: "NXS",
    title: "キャンパスの旅、チェックイン完了",
    subtitle: "各スポットでコードを読み取って回遊を始めましょう",
    footer: "Today",
    muted: "電波が弱い場合は手入力が使えます",
  });
  ticketWrap.append(ticketTitle, ticketCard);

  const eventsBlock = createCard("今日のイベント");
  const eventsContent = document.createElement("div");
  eventsContent.className = "grid";
  eventsBlock.appendChild(eventsContent);
  eventsContent.appendChild(createSkeletonList());

  void getTodayEvents()
    .then((events) => {
      renderEvents(eventsContent, events);
    })
    .catch((err) => {
      eventsContent.textContent = "イベント情報の取得に失敗しました。後ほどお試しください。";
      console.error(err);
    });

  page.append(heroCard, form, quickRow, ticketWrap, eventsBlock);
  return page;
};

const createSkeletonList = (): HTMLElement => {
  const skeleton = document.createElement("div");
  skeleton.className = "grid";
  for (let i = 0; i < 2; i++) {
    const block = document.createElement("div");
    block.className = "skeleton";
    block.style.height = "72px";
    block.style.borderRadius = "14px";
    skeleton.appendChild(block);
  }
  return skeleton;
};
