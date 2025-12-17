import iconHome from "../assets/ui-kit/icons/home.svg";
import iconLocation from "../assets/ui-kit/icons/location.svg";
import iconList from "../assets/ui-kit/icons/list.svg";
import iconPlane from "../assets/ui-kit/icons/plane.svg";
import iconClock from "../assets/ui-kit/icons/clock.svg";

type NavItem = { path: string; label: string; icon: string };

const navItems: NavItem[] = [
  { path: "/", label: "ホーム", icon: iconHome },
  { path: "/nearby", label: "周辺", icon: iconLocation },
  { path: "/events", label: "イベント", icon: iconList },
  { path: "/reserve", label: "予約", icon: iconPlane },
  { path: "/status", label: "状況", icon: iconClock },
];

export const createBottomNav = (currentPath: string, onNavigate: (path: string) => void): HTMLElement => {
  const nav = document.createElement("nav");
  nav.className = "bottom-nav surface glass";

  navItems.forEach((item) => {
    const btn = document.createElement("button");
    const isActive = currentPath === item.path || (item.path === "/" && currentPath === "/");
    btn.className = `bottom-nav__item md-ripple ${isActive ? "is-active" : ""}`;
    btn.innerHTML = `
      <span class="nav-icon"><img src="${item.icon}" alt="" /></span>
      <span class="nav-label">${item.label}</span>
    `;
    btn.addEventListener("click", () => onNavigate(item.path));
    nav.appendChild(btn);
  });
  return nav;
};

export const bottomNavStyles = `
:root {
  --nav-active-offset: -6px;
  --nav-active-scale: 1.1;
}
.bottom-nav {
  position: fixed;
  inset: auto 0 0 0;
  z-index: 20;
  display: grid;
  grid-template-columns: repeat(5, 1fr);
  gap: 0;
  padding: 10px 6px;
  border-radius: 22px 22px 0 0;
  border: 1px solid var(--border);
  box-shadow: 0 -8px 24px rgba(12, 52, 140, 0.08);
  max-width: 520px;
  margin: 0 auto;
  background: rgba(255, 255, 255, 0.94);
}
.bottom-nav__item {
  position: relative;
  display: grid;
  justify-items: center;
  gap: 6px;
  padding: 10px 4px 8px;
  border-radius: 999px;
  border: none;
  background: transparent;
  color: var(--muted);
  font-weight: 700;
  font-size: 0.85rem;
  transition: color 200ms cubic-bezier(0.2, 0, 0, 1), 
              transform 200ms cubic-bezier(0.2, 0, 0, 1);
              boxshadow 200ms cubic-bezier(0.2, 0, 0, 1);
}
.bottom-nav__item .nav-icon {
  width: 24px;
  height: 24px;
  display: grid;
  place-items: center;
  position: relative;
  z-index: 1;
  transition: transform 200ms cubic-bezier(0.2, 0, 0, 1);
}
.bottom-nav__item .nav-icon img {
  width: 100%;
  height: 100%;
  filter: grayscale(0.5) opacity(0.8);
  transition: filter 200ms cubic-bezier(0.2, 0, 0, 1);
  }
  .bottom-nav__item::before {
    content: "";
    position: absolute;
    top: 6px;
    left: 50%;
    width: 48px;
    height: 48px;
    border-radius: 999px;
    background: rgba(255, 255, 255, 0.6);
    box-shadow:
      0 10px 28px rgba(12, 52, 140, 0.16),
      0 4px 10px rgba(12, 52, 140, 0.08);
    opacity: 0;
    transform: translate(-50%, 4px) scale(0.9);
    transition: transform 200ms cubic-bezier(0.2, 0, 0, 1),
                opacity 200ms cubic-bezier(0.2, 0, 0, 1),
                box-shadow 200ms cubic-bezier(0.2, 0, 0, 1);
    pointer-events: none;
  }
  .bottom-nav__item.is-active {
    color: var(--primary);
    transform: translateY(-3px);
  }
}
  }
  .bottom-nav__item::before {
    content: "";
    position: absolute;
    top: 6px;
    left: 50%;
    width: 48px;
    height: 48px;
    border-radius: 999px;
    background: rgba(255, 255, 255, 0.6);
    box-shadow:
      0 10px 28px rgba(12, 52, 140, 0.16),
      0 4px 10px rgba(12, 52, 140, 0.08);
    opacity: 0;
    transform: translate(-50%, 4px) scale(0.9);
    transition: transform 200ms cubic-bezier(0.2, 0, 0, 1),
                opacity 200ms cubic-bezier(0.2, 0, 0, 1),
                box-shadow 200ms cubic-bezier(0.2, 0, 0, 1);
    pointer-events: none;
  }
  .bottom-nav__item.is-active {
    color: var(--primary);
    transform: translateY(-3px);
  }
}
  }
  .bottom-nav__item::before {
    content: "";
    position: absolute;
    top: 6px;
    left: 50%;
    width: 48px;
    height: 48px;
    border-radius: 999px;
    background: rgba(255, 255, 255, 0.6);
    box-shadow:
      0 10px 28px rgba(12, 52, 140, 0.16),
      0 4px 10px rgba(12, 52, 140, 0.08);
    opacity: 0;
    transform: translate(-50%, 4px) scale(0.9);
    transition: transform 200ms cubic-bezier(0.2, 0, 0, 1),
                opacity 200ms cubic-bezier(0.2, 0, 0, 1),
                box-shadow 200ms cubic-bezier(0.2, 0, 0, 1);
    pointer-events: none;
  }
  .bottom-nav__item.is-active {
    color: var(--primary);
    transform: translateY(-3px);
  }
.bottom-nav__item.is-active .nav-icon img {
  filter: none;
}
.nav-label { line-height: 1; }
@media (prefers-reduced-motion: reduce) {
  .bottom-nav__item,
  .bottom-nav__item .nav-icon {
    transition: none;
    transform: none;
  }
  .bottom-nav__item::before {
    transition: none;
    transform: translate(-50%, 0);
  }
}
`;
