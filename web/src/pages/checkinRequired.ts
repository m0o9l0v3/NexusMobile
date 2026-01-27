import { createCard } from "../components/card";

export const renderCheckinRequired = (): HTMLElement => {
  const page = document.createElement("div");
  page.className = "grid";

  const card = createCard(
    "チェックインが必要です",
    `
      <p class="muted">このページを利用するには、公式QRコードからチェックインしてください。</p>
      <p class="muted">QRコードを再度読み取り、案内に従ってください。</p>
    `,
  );

  page.append(card);
  return page;
};
