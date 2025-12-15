import { createCard } from "../components/card";
import { getTodayEvents } from "../lib/api";
import type { EventItem } from "../types";

export const renderEventsPage = (): HTMLElement => {
  const page = document.createElement("div");
  page.className = "grid";
  const card = createCard("今日のイベント");
  const body = document.createElement("div");
  body.className = "grid";
  card.appendChild(body);
  page.appendChild(card);

  body.appendChild(createSkeleton());
  void getTodayEvents()
    .then((events) => {
      body.innerHTML = "";
      if (!events.length) {
        body.textContent = "イベント情報は準備中です。";
        return;
      }
      events.forEach((evt) => body.appendChild(renderEvent(evt)));
    })
    .catch(() => {
      body.textContent = "取得に失敗しました。時間をおいて再度お試しください。";
    });

  return page;
};

const renderEvent = (evt: EventItem): HTMLElement => {
  const card = createCard();
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
  return card;
};

const createSkeleton = (): HTMLElement => {
  const block = document.createElement("div");
  block.className = "skeleton";
  block.style.height = "96px";
  block.style.borderRadius = "14px";
  return block;
};
