import { createBadge } from "../components/badge";
import { createButton } from "../components/button";
import { createCard } from "../components/card";
import { getNearby } from "../lib/api";
import { getCurrentPosition } from "../lib/location";
import { logEvent } from "../lib/logger";
import type { NearbyItem } from "../types";

export const renderNearby = (): HTMLElement => {
  const page = document.createElement("div");
  page.className = "grid";

  const info = createCard("周辺スポット");
  const infoBody = document.createElement("div");
  infoBody.innerHTML = `
    <p>現在地に近いスポット・イベントを距離順に表示します。</p>
    <p class="muted">位置情報を拒否した場合でも、手入力で検索できます。</p>
  `;
  info.appendChild(infoBody);

  const actionRow = document.createElement("div");
  actionRow.className = "row";
  const listArea = document.createElement("div");
  listArea.className = "grid";
  listArea.appendChild(createSkeleton());

  const fetchNearby = async () => {
    listArea.innerHTML = "";
    listArea.appendChild(createSkeleton());
    try {
      const pos = await getCurrentPosition();
      logEvent({ type: "nearby_impression", payload: { accuracy: pos.accuracy } });
      listArea.innerHTML = "";
      if (pos.accuracy) {
        const badge = createBadge(`accuracy ±${Math.round(pos.accuracy)}m`, "success");
        listArea.appendChild(badge);
      }
      const items = await getNearby(pos.latitude, pos.longitude, 450);
      renderNearbyList(listArea, items);
    } catch (error) {
      console.error(error);
      listArea.innerHTML = "";
      listArea.textContent = "位置情報が許可されませんでした。ホームからコード入力もご利用ください。";
    }
  };

  const requestBtn = createButton({
    label: "現在地を取得",
    variant: "primary",
    onClick: fetchNearby,
  });
  actionRow.appendChild(requestBtn);

  page.append(info, actionRow, listArea);
  return page;
};

const renderNearbyList = (target: HTMLElement, items: NearbyItem[]) => {
  if (!items.length) {
    target.textContent = "近くにスポット情報がありませんでした。";
    return;
  }
  const list = document.createElement("div");
  list.className = "grid";
  items
    .sort((a, b) => a.distanceM - b.distanceM)
    .forEach((item) => {
      const card = createCard();
      card.classList.add("near-card");
      card.innerHTML = `
        <div class="row space-between">
          <div>
            <div class="near-card__title">${item.name}</div>
            <div class="muted">${item.category === "event" ? "イベント" : "スポット"} ${
              item.time ? ` / ${item.time}` : ""
            }</div>
          </div>
          <div class="near-card__distance tabular">${Math.round(item.distanceM)}m</div>
        </div>
        <div class="muted">推定精度 ±${Math.round(item.accuracyM)}m</div>
      `;
      list.appendChild(card);
    });
  target.appendChild(list);
};

const createSkeleton = () => {
  const block = document.createElement("div");
  block.className = "skeleton";
  block.style.height = "120px";
  block.style.borderRadius = "14px";
  return block;
};
