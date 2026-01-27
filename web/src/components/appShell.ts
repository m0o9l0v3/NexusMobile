type ShellOptions = {
  onNavigate: (path: string) => void;
  currentPath: string;
};

import iconBell from "../assets/ui-kit/icons/bell.svg";

export const createAppShell = (options: ShellOptions): HTMLElement => {
  const header = document.createElement("header");
  header.className = "app-shell glass";

  const top = document.createElement("div");
  top.className = "app-shell__top";

  const left = document.createElement("button");
  left.className = "icon-btn md-ripple";
  left.setAttribute("aria-label", "メニュー");
  left.innerHTML = `<span class="icon icon-menu"></span>`;

  const brand = document.createElement("div");
  brand.className = "app-shell__brand";
  brand.innerHTML = `<div class="brand-mark">N</div><div class="brand-text">Nexus</div>`;

  const bell = document.createElement("span");
  bell.className = "icon-img";
  bell.innerHTML = `<img src="${iconBell}" alt="" />`;

  const right = document.createElement("button");
  right.className = "icon-btn md-ripple";
  right.setAttribute("aria-label", "通知");
  right.append(bell);
  right.innerHTML += `<span class="dot"></span>`;
  right.addEventListener("click", () => options.onNavigate("/app/events"));

  top.append(left, brand, right);

  header.append(top);
  return header;
};

export const appShellStyles = `
.app-shell {
  position: sticky;
  top: 0;
  z-index: 10;
  display: grid;
  padding: 14px;
  border-radius: 24px;
  border: 1px solid rgba(12,52,140,0.08);
  background: linear-gradient(180deg, #e9f3ff 0%, #f6faff 100%);
  box-shadow: var(--shadow-soft);
  backdrop-filter: var(--surface-blur);
  -webkit-backdrop-filter: var(--surface-blur);
}
.app-shell__top {
  display: grid;
  grid-template-columns: auto 1fr auto;
  align-items: center;
}
.app-shell__brand {
  display: grid;
  justify-items: center;
  gap: 6px;
  font-weight: 800;
  letter-spacing: 0.06em;
}
.brand-mark {
  width: 36px;
  height: 36px;
  border-radius: 12px;
  background: linear-gradient(135deg, var(--primary), var(--primary-2));
  color: #fff;
  display: grid;
  place-items: center;
  font-weight: 800;
  box-shadow: 0 8px 24px rgba(12, 52, 140, 0.2);
}
.brand-text {
  font-weight: 800;
  color: var(--primary);
}
.icon-btn {
  width: 42px;
  height: 42px;
  border-radius: 16px;
  border: 1px solid var(--border);
  background: #ffffff;
  display: grid;
  place-items: center;
  position: relative;
  box-shadow: var(--elev-1);
}
.icon {
  display: inline-block;
  width: 18px;
  height: 18px;
  border-radius: 2px;
  border: 2px solid var(--primary);
  position: relative;
}
.icon-menu {
  border: none;
}
.icon-menu::before,
.icon-menu::after {
  content: "";
  position: absolute;
  left: 0;
  right: 0;
  height: 2px;
  background: var(--primary);
  border-radius: 999px;
}
.icon-menu::before { top: 4px; }
.icon-menu::after { bottom: 4px; }
.icon-img {
  width: 18px;
  height: 18px;
  display: grid;
  place-items: center;
}
.icon-img img {
  width: 100%;
  height: 100%;
  display: block;
}
.icon-btn .dot {
  position: absolute;
  top: 6px;
  right: 6px;
  width: 8px;
  height: 8px;
  border-radius: 999px;
  background: var(--danger);
  box-shadow: 0 0 0 4px rgba(225, 29, 72, 0.12);
}
`;
