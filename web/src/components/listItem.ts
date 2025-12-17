export type ListItemProps = {
  title: string;
  subtitle?: string;
  meta?: string;
  leadingIcon?: string;
  trailingIcon?: string;
};

export const createListItem = (props: ListItemProps): HTMLElement => {
  const item = document.createElement("div");
  item.className = "list-item md-ripple";
  item.innerHTML = `
    ${props.leadingIcon ? `<img class="list-item__icon" src="${props.leadingIcon}" alt="" />` : ""}
    <div class="list-item__body">
      <div class="list-item__title">${props.title}</div>
      ${props.subtitle ? `<div class="list-item__subtitle">${props.subtitle}</div>` : ""}
    </div>
    ${props.meta ? `<div class="list-item__meta">${props.meta}</div>` : ""}
    ${props.trailingIcon ? `<img class="list-item__icon" src="${props.trailingIcon}" alt="" />` : ""}
  `;
  return item;
};

export const listItemStyles = `
.list-item {
  display: grid;
  grid-template-columns: auto 1fr auto auto;
  gap: 10px;
  align-items: center;
  padding: 12px 14px;
  border-radius: var(--radius);
  border: 1px solid var(--border);
  background: var(--surface);
  box-shadow: var(--elev-1);
}
.list-item__icon {
  width: 26px;
  height: 26px;
}
.list-item__title {
  font-weight: 700;
  color: var(--text);
}
.list-item__subtitle {
  color: var(--muted);
  font-size: 0.9rem;
}
.list-item__meta {
  color: var(--primary);
  font-weight: 700;
}
`;
