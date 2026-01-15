export type SegmentOption = {
  value: string;
  label: string;
};

export const createSegmentedControl = (
  options: SegmentOption[],
  active: string,
  onChange: (value: string) => void,
): HTMLElement => {
  const wrap = document.createElement("div");
  wrap.className = "segmented";

  options.forEach((opt) => {
    const btn = document.createElement("button");
    btn.className = `segmented__item ${opt.value === active ? "is-active" : ""} md-ripple`;
    btn.textContent = opt.label;
    btn.addEventListener("click", () => onChange(opt.value));
    wrap.appendChild(btn);
  });

  return wrap;
};

export const segmentedStyles = `
.segmented {
  display: grid;
  grid-auto-flow: column;
  grid-auto-columns: 1fr;
  border-radius: 999px;
  background: var(--surface-2);
  border: 1px solid var(--border);
  padding: 4px;
}
.segmented__item {
  border: none;
  background: transparent;
  padding: 10px 12px;
  border-radius: 999px;
  font-weight: 700;
  color: var(--muted);
  transition: color 180ms ease, transform 180ms ease, background 180ms ease;
}
.segmented__item.is-active {
  color: var(--primary);
  background: #fff;
  box-shadow: var(--elev-1);
  transform: translateY(-1px);
}
@media (prefers-reduced-motion: reduce) {
  .segmented__item,
  .segmented__item.is-active {
    transform: none;
    transition: none;
  }
}
`;
