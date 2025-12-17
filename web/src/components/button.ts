type ButtonOptions = {
  label: string;
  variant?: "primary" | "secondary" | "ghost";
  onClick?: () => void;
  icon?: string;
  ariaLabel?: string;
};

export const createButton = (options: ButtonOptions): HTMLButtonElement => {
  const btn = document.createElement("button");
  btn.className = `btn btn--${options.variant ?? "primary"} motion-soft`;
  btn.type = "button";
  btn.textContent = options.label;
  if (options.icon) {
    const span = document.createElement("span");
    span.className = "btn__icon";
    span.textContent = options.icon;
    btn.prepend(span);
  }
  if (options.ariaLabel) {
    btn.setAttribute("aria-label", options.ariaLabel);
  }
  if (options.onClick) {
    btn.addEventListener("click", options.onClick);
  }
  return btn;
};

export const buttonStyles = `
.btn {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  padding: 12px 18px;
  border-radius: 999px;
  font-weight: 700;
  letter-spacing: 0.01em;
  border: 1px solid transparent;
  position: relative;
  overflow: hidden;
  box-shadow: var(--elev-1);
}
.btn--primary {
  background: var(--primary);
  color: var(--primary-contrast);
  box-shadow: var(--elev-2);
}
.btn--secondary {
  background: var(--primary-container);
  color: var(--primary);
  border-color: rgba(12, 52, 140, 0.12);
}
.btn--ghost {
  background: transparent;
  color: var(--primary);
  border: 1px solid var(--outline);
}
.btn:active {
  transform: translateY(1px);
}
@media (hover: hover) {
  .btn:hover { filter: saturate(1.05); }
}
.btn::after {
  content: "";
  position: absolute;
  inset: 0;
  background: transparent;
  transition: background 160ms ease;
  pointer-events: none;
}
@media (hover: hover) {
  .btn:hover::after { background: var(--state-hover); }
}
.btn:active::after { background: var(--state-pressed); }
`;
