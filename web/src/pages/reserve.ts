import { createButton } from "../components/button";
import { createCard } from "../components/card";
import { createInputField } from "../components/inputField";
import { createSegmentedControl } from "../components/segmentedControl";

export const renderReserve = (): HTMLElement => {
  const page = document.createElement("div");
  page.className = "grid";

  const card = createCard("予約フォーム");
  const body = document.createElement("div");
  body.className = "grid";

  const tripType = createSegmentedControl(
    [
      { value: "oneway", label: "片道" },
      { value: "round", label: "往復" },
    ],
    "oneway",
    () => {},
  );

  const from = createInputField({ label: "出発地", placeholder: "例: HND" });
  const to = createInputField({ label: "到着地", placeholder: "例: CTS" });
  const date = createInputField({ label: "出発日", placeholder: "YYYY-MM-DD", type: "date" });
  const searchBtn = createButton({ label: "検索する", variant: "primary" });

  body.append(tripType, from, to, date, searchBtn);
  card.appendChild(body);
  page.appendChild(card);
  return page;
};
