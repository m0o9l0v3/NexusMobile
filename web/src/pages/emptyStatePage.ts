import { createEmptyState } from "../components/emptyState";

export const renderEmptyStatePage = (): HTMLElement => {
  const page = document.createElement("div");
  page.className = "grid";
  page.appendChild(
    createEmptyState({
      title: "まだ表示できる情報がありません",
      description: "QRコードを読み取るか、予約や周辺をチェックしてください。",
    }),
  );
  return page;
};
