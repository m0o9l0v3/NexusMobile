import { createBadge } from "../components/badge";
import { createButton } from "../components/button";
import { createCard } from "../components/card";
import { createTicketCard } from "../components/ticketCard";
import { createModal, type ModalHandle } from "../components/modal";
import { showToast } from "../components/toast";
import { getSpotByCode } from "../lib/api";
import { logEvent } from "../lib/logger";
import type { Spot } from "../types";

export const openSpotModal = async (code: string, onClose: () => void): Promise<ModalHandle | null> => {
  const loading = createCard("スポットを開いています…");
  loading.classList.add("skeleton");
  loading.style.height = "220px";
  const modal = createModal(loading, onClose);
  try {
    const spot = await getSpotByCode(code);
    logEvent({ type: "spot_view", payload: { code } });
    const detail = buildSpotContent(spot);
    modal.element.querySelector(".modal")?.replaceChildren(detail);
    return modal;
  } catch (err) {
    console.error(err);
    modal.close();
    showToast({ message: "スポットが見つかりません", tone: "danger" });
    return null;
  }
};

const buildSpotContent = (spot: Spot): HTMLElement => {
  const wrap = document.createElement("div");
  wrap.className = "grid";

  const header = createTicketCard({
    code: spot.code,
    title: spot.name,
    subtitle: "スポット詳細",
    footer: "Nexus",
    muted: "コードが読めない場合は手入力を使ってください",
  });

  const body = createCard();
  body.innerHTML = `
    <div class="spot__info">
      <div class="spot__text">
        <h2>${spot.name}</h2>
        <p class="muted">${spot.description}</p>
        <div class="row spot__tags"></div>
      </div>
      ${
        spot.image
          ? `<img src="${spot.image}" alt="${spot.name}" loading="lazy" class="spot__image" />`
          : "<div class='skeleton' style='height:140px;border-radius:14px;'></div>"
      }
    </div>
  `;
  const tagRow = body.querySelector(".spot__tags") as HTMLElement;
  (spot.tags ?? []).forEach((tag) => {
    const badge = createBadge(tag, "info");
    tagRow.appendChild(badge);
  });

  if (spot.links?.length) {
    const linkList = document.createElement("div");
    linkList.className = "grid";
    spot.links.forEach((link) => {
      const btn = createButton({ label: link.label, variant: "ghost" });
      btn.addEventListener("click", () => window.open(link.url, "_blank"));
      linkList.appendChild(btn);
    });
    body.appendChild(linkList);
  }

  wrap.append(header, body);
  return wrap;
};
