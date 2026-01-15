import { createCard } from "../components/card";
import { createListItem } from "../components/listItem";
import iconPlane from "../assets/ui-kit/icons/plane.svg";
import iconClock from "../assets/ui-kit/icons/clock.svg";

export const renderStatus = (): HTMLElement => {
  const page = document.createElement("div");
  page.className = "grid";

  const card = createCard("運航状況");
  const list = document.createElement("div");
  list.className = "grid";

  const items = [
    { title: "NXS101 / 東京 → 札幌", subtitle: "定刻 10:30 / 出発済み", meta: "On-time", icon: iconPlane },
    { title: "NXS202 / 東京 → 福岡", subtitle: "定刻 12:10 / 出発待ち", meta: "Gate 21", icon: iconClock },
  ];

  items.forEach((it) => {
    list.appendChild(
      createListItem({
        title: it.title,
        subtitle: it.subtitle,
        meta: it.meta,
        leadingIcon: it.icon,
      }),
    );
  });

  card.appendChild(list);
  page.appendChild(card);
  return page;
};
