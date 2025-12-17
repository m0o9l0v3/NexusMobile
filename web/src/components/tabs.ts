export type TabOption = { value: string; label: string };

export const createTabs = (options: TabOption[], active: string, onChange: (value: string) => void): HTMLElement => {
  const wrap = document.createElement("div");
  wrap.className = "tabs";

  const slider = document.createElement("div");
  slider.className = "tabs__slider";
  wrap.appendChild(slider);

  options.forEach((opt, index) => {
    const btn = document.createElement("button");
    btn.className = `tabs__item md-ripple ${opt.value === active ? "is-active" : ""}`;
    btn.textContent = opt.label;
    btn.addEventListener("click", () => onChange(opt.value));
    btn.dataset.index = String(index);
    wrap.appendChild(btn);
  });

  requestAnimationFrame(() => updateSlider(wrap, slider));

  const observer = new MutationObserver(() => updateSlider(wrap, slider));
  observer.observe(wrap, { attributes: true, subtree: true, attributeFilter: ["class"] });

  return wrap;
};

const updateSlider = (wrap: HTMLElement, slider: HTMLElement) => {
  const active = wrap.querySelector<HTMLElement>(".tabs__item.is-active");
  if (!active) return;
  const rect = active.getBoundingClientRect();
  const wrapRect = wrap.getBoundingClientRect();
  slider.style.width = `${rect.width}px`;
  slider.style.transform = `translateX(${rect.left - wrapRect.left}px)`;
};

export const tabsStyles = `
.tabs {
  position: relative;
  display: grid;
  grid-auto-flow: column;
  grid-auto-columns: 1fr;
  border-bottom: 1px solid var(--border);
  gap: 4px;
}
.tabs__item {
  border: none;
  background: transparent;
  padding: 12px 6px;
  color: var(--muted);
  font-weight: 700;
}
.tabs__item.is-active {
  color: var(--primary);
}
.tabs__slider {
  position: absolute;
  height: 3px;
  border-radius: 999px;
  background: linear-gradient(135deg, var(--primary), var(--primary-2));
  bottom: -1px;
  left: 0;
  transition: transform 200ms cubic-bezier(0.2, 0, 0, 1), width 200ms cubic-bezier(0.2, 0, 0, 1);
}
@media (prefers-reduced-motion: reduce) {
  .tabs__slider { transition: none; }
}
`;
