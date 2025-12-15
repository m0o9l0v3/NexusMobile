import { createButton } from "./button";

type ShellOptions = {
  onToggleTheme: () => void;
  onNavigate: (path: string) => void;
  currentPath: string;
};

const navItems = [
  { path: "/", label: "Home" },
  { path: "/nearby", label: "Nearby" },
  { path: "/events", label: "Events" },
];

export const createAppShell = (options: ShellOptions): HTMLElement => {
  const header = document.createElement("header");
  header.className = "app-shell surface glass";

  const brand = document.createElement("div");
  brand.className = "app-shell__brand";
  brand.innerHTML = `<div class="dot"></div><span>Nexus</span>`;

  const nav = document.createElement("nav");
  nav.className = "app-shell__nav";
  navItems.forEach((item) => {
    const btn = document.createElement("button");
    btn.className = `nav-link ${options.currentPath === item.path ? "is-active" : ""}`;
    btn.textContent = item.label;
    btn.addEventListener("click", () => options.onNavigate(item.path));
    nav.appendChild(btn);
  });

  const actions = document.createElement("div");
  actions.className = "app-shell__actions";
  const themeBtn = createButton({
    label: "Theme",
    variant: "secondary",
    ariaLabel: "Toggle theme",
    onClick: options.onToggleTheme,
  });
  themeBtn.classList.add("compact");
  actions.appendChild(themeBtn);

  header.append(brand, nav, actions);
  return header;
};

export const appShellStyles = `
.app-shell {
  position: sticky;
  top: 0;
  z-index: 10;
  display: grid;
  align-items: center;
  grid-template-columns: auto 1fr auto;
  gap: var(--space-3);
  padding: 12px 16px;
  border-radius: var(--radius-lg);
  border: 1px solid var(--border);
  backdrop-filter: var(--surface-blur);
  -webkit-backdrop-filter: var(--surface-blur);
}
.app-shell__brand {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  font-weight: 800;
  letter-spacing: 0.08em;
}
.app-shell__brand .dot {
  width: 12px;
  height: 12px;
  border-radius: 50%;
  background: linear-gradient(135deg, var(--primary), var(--primary-2));
  box-shadow: 0 0 0 6px rgba(74, 163, 255, 0.18);
}
.app-shell__nav {
  display: flex;
  gap: 8px;
  justify-content: center;
}
.nav-link {
  padding: 10px 12px;
  border-radius: 12px;
  border: 1px solid transparent;
  color: var(--text);
  background: transparent;
}
.nav-link.is-active {
  border-color: var(--border);
  background: var(--surface-2);
}
.app-shell__actions {
  display: flex;
  gap: 8px;
  justify-content: flex-end;
}
.btn.compact {
  padding-inline: 12px;
}
@media (max-width: 720px) {
  .app-shell {
    grid-template-columns: 1fr auto;
    grid-template-rows: auto auto;
  }
  .app-shell__nav {
    grid-column: 1 / -1;
    justify-content: flex-start;
  }
}
`;
