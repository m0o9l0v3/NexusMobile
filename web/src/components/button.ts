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
  padding: 11px 16px;
  border-radius: 999px;
  font-weight: 700;
  letter-spacing: 0.01em;
}
.btn--primary {
  background: linear-gradient(135deg, var(--primary), var(--primary-2));
  color: #ffffff;
  box-shadow: 0 12px 28px rgba(12, 52, 140, 0.18);
}
.btn--secondary {
  background: var(--surface);
  color: var(--text);
  border: 1px solid var(--border);
}
.btn--ghost {
  background: transparent;
  color: var(--text);
  border: 1px dashed var(--border);
}
.btn:active {
  transform: translateY(1px);
}
`;
