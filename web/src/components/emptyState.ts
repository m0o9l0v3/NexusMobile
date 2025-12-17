import emptyIllustration from "../assets/ui-kit/illustrations/empty.svg";
import { createButton } from "./button";

type EmptyProps = {
  title: string;
  description: string;
  actionLabel?: string;
  onAction?: () => void;
};

export const createEmptyState = (props: EmptyProps): HTMLElement => {
  const wrap = document.createElement("div");
  wrap.className = "empty-state surface md-ripple";
  wrap.innerHTML = `
    <img src="${emptyIllustration}" alt="" class="empty-state__img" />
    <div class="empty-state__title">${props.title}</div>
    <div class="empty-state__desc">${props.description}</div>
  `;
  if (props.actionLabel && props.onAction) {
    const btn = createButton({ label: props.actionLabel, variant: "secondary", onClick: props.onAction });
    btn.classList.add("btn-small");
    wrap.appendChild(btn);
  }
  return wrap;
};

export const emptyStateStyles = `
.empty-state {
  display: grid;
  justify-items: center;
  gap: 12px;
  padding: 18px;
  text-align: center;
  border-radius: var(--radius-lg);
}
.empty-state__img {
  width: 220px;
  max-width: 100%;
}
.empty-state__title {
  font-weight: 800;
  color: var(--text);
}
.empty-state__desc {
  color: var(--muted);
}
`;
