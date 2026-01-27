import "./styles/design-tokens.css";
import "./styles/base.css";
import { appShellStyles, createAppShell } from "./components/appShell";
import { badgeStyles } from "./components/badge";
import { buttonStyles } from "./components/button";
import { cardStyles } from "./components/card";
import { modalStyles } from "./components/modal";
import { ticketStyles } from "./components/ticketCard";
import { showToast, toastStyles } from "./components/toast";
import { bottomNavStyles, createBottomNav } from "./components/bottomNav";
import { segmentedStyles } from "./components/segmentedControl";
import { tabsStyles } from "./components/tabs";
import { listItemStyles } from "./components/listItem";
import { inputFieldStyles } from "./components/inputField";
import { emptyStateStyles } from "./components/emptyState";
import { attachRipple, rippleStyles } from "./components/ripple";
import { setupLogRetry } from "./lib/logger";
import { openSpotModal } from "./pages/spot";
import { renderHome } from "./pages/home";
import { renderNearby } from "./pages/nearby";
import { renderEventsPage } from "./pages/events";
import { renderReserve } from "./pages/reserve";
import { renderStatus } from "./pages/status";
import { renderEmptyStatePage } from "./pages/emptyStatePage";
import { renderCheckinPage } from "./pages/checkin";
import { renderCheckinRequired } from "./pages/checkinRequired";
import { isWebRuntime } from "./lib/runtime";
import { clearCheckinProfile, isCheckedIn } from "./lib/checkin";

type Route = "/" | "/nearby" | "/events" | "/reserve" | "/status" | "/empty";
type CheckinState = {
  checkedIn: boolean;
  code?: string;
  checkedAt?: string;
};

const CHECKIN_STORAGE_KEY = "nexus-checkin-state";
const THEME_STORAGE_KEY = "nexus-theme";

const componentStyles = [
  appShellStyles,
  badgeStyles,
  buttonStyles,
  cardStyles,
  modalStyles,
  ticketStyles,
  toastStyles,
  bottomNavStyles,
  segmentedStyles,
  tabsStyles,
  listItemStyles,
  inputFieldStyles,
  emptyStateStyles,
  rippleStyles,
  `
  main {
    display: grid;
    gap: var(--space-3);
    margin-top: var(--space-3);
  }
  .space-between { justify-content: space-between; }
  .event-card__title { font-weight: 700; font-size: 1rem; }
  .near-card__title { font-weight: 700; font-size: 1rem; }
  .near-card__distance { font-weight: 800; }
  .spot__info { display: grid; gap: 12px; align-items: start; }
  .spot__image { border-radius: 14px; object-fit: cover; width: 100%; max-height: 200px; }
  @media (min-width: 640px) { .spot__info { grid-template-columns: 1fr 0.7fr; } }
  .hero-panel {
    display: grid;
    gap: 10px;
    padding: 18px;
    border-radius: 24px;
    background: linear-gradient(135deg, rgba(74, 163, 255, 0.22), rgba(12, 52, 140, 0.12));
    border: 1px solid rgba(12,52,140,0.08);
    box-shadow: var(--shadow-soft);
  }
  .hero-avatar {
    width: 48px;
    height: 48px;
    border-radius: 18px;
    background: linear-gradient(135deg, rgba(255,255,255,0.94), rgba(214,238,255,0.9));
    display: grid;
    place-items: center;
    border: 1px solid var(--border);
    box-shadow: inset 0 1px 0 rgba(255,255,255,0.9);
  }
  .hero-avatar::after {
    content: "";
    width: 22px;
    height: 22px;
    background: radial-gradient(circle at 50% 40%, var(--primary) 0 60%, rgba(12,52,140,0.2) 61% 100%);
    border-radius: 50%;
  }
  .hero-title { font-size: 1.1rem; font-weight: 800; color: var(--primary); }
  .status-panel {
    display: grid;
    gap: 8px;
    padding: 14px;
    border-radius: 20px;
    background: rgba(255,255,255,0.9);
    border: 1px solid var(--border);
    box-shadow: var(--shadow-soft);
  }
  .status-panel__row {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: var(--space-2);
  }
  .status-chip {
    padding: 4px 10px;
    border-radius: 999px;
    font-size: 0.85rem;
    font-weight: 700;
    background: rgba(12,52,140,0.12);
    color: var(--primary);
  }
  .status-meta {
    font-size: 0.85rem;
    color: var(--muted);
  }
  .section-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: var(--space-2);
  }
  .btn-small { padding: 8px 12px; font-size: 0.9rem; }
  .featured-card {
    min-height: 140px;
    border-radius: 22px;
    box-shadow: var(--shadow-card);
    display: grid;
    align-content: space-between;
    padding: 14px;
  }
  @media (hover: hover) {
    .featured-card:hover { transform: translateY(-1px); }
  }
  .featured-card:active { transform: translateY(0px); }
  .featured-title { font-weight: 800; font-size: 1rem; color: var(--text); }
  .quick-actions {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(90px, 1fr));
    gap: var(--space-2);
  }
  .quick-btn {
    border: 1px solid var(--border);
    border-radius: 16px;
    padding: 12px 8px;
    display: grid;
    justify-items: center;
    gap: 6px;
    background: #fff;
    box-shadow: var(--elev-1);
  }
  .quick-icon {
    width: 44px;
    height: 44px;
    border-radius: 14px;
    display: grid;
    place-items: center;
    background: linear-gradient(135deg, rgba(74,163,255,0.15), rgba(12,52,140,0.15));
    color: var(--primary);
    font-size: 1.1rem;
  }
  .quick-label {
    font-weight: 700;
    color: var(--text);
    font-size: 0.9rem;
  }
  .small { font-size: 0.92rem; }
  .form-errors {
    padding: 12px;
    border-radius: 12px;
    background: rgba(225, 29, 72, 0.08);
    color: var(--danger);
    border: 1px solid rgba(225, 29, 72, 0.16);
    font-size: 0.9rem;
  }
  .form-errors ul { margin: 0; padding-left: 18px; }
  .form-error { border-color: rgba(225, 29, 72, 0.24); }
  .full-width { width: 100%; }
  .btn.is-loading {
    opacity: 0.7;
    pointer-events: none;
  }
  `,
].join("\n");

const style = document.createElement("style");
style.textContent = componentStyles;
document.head.appendChild(style);

const root = document.querySelector<HTMLDivElement>("#app");
if (!root) throw new Error("app container missing");

enforceLightTheme();

const sanitizeRoute = (path: string): Route => {
  if (path === "/nearby" || path === "/events" || path === "/reserve" || path === "/status" || path === "/empty") return path;
  return "/";
};

const parseRoute = (url: URL): Route => {
  if (url.pathname === "/checkin") {
    const token = url.searchParams.get("token") ?? undefined;
    return { kind: "checkin", token };
  }
  if (url.pathname === "/" || url.pathname.startsWith("/app")) {
    const path = url.pathname === "/" ? "/app" : sanitizeAppRoute(url.pathname);
    return { kind: "app", path };
  }
  return { kind: "app", path: "/app" };
};

let currentRoute: Route = parseRoute(new URL(window.location.href));
let spotModal: Awaited<ReturnType<typeof openSpotModal>> | null = null;
let qrHandle: QrHandle | null = null;
let checkinState: CheckinState = readCheckinState();

const main = document.createElement("main");

const updateUrl = (path: string, searchParams?: URLSearchParams, replace = false) => {
  const url = new URL(window.location.href);
  url.pathname = path;
  url.search = searchParams?.toString() ? `?${searchParams.toString()}` : "";
  if (replace) {
    window.history.replaceState({}, "", url);
  } else {
    window.history.pushState({}, "", url);
  }
  currentRoute = parseRoute(url);
  render();
};

const navigate = (path: string) => {
  updateUrl(path);
};

const navigateToCheckin = (token?: string, replace = false) => {
  const params = new URLSearchParams();
  if (token) params.set("token", token);
  updateUrl("/checkin", params, replace);
};

const navigateToApp = (path: AppRoute, replace = false) => {
  updateUrl(path, undefined, replace);
};

const handleCodeOpen = (code: string) => {
  const url = new URL(window.location.href);
  url.searchParams.set("code", code);
  window.history.pushState({}, "", url);
  setCheckinState(code);
  render();
};

const openSpotFromUrl = async () => {
  const code = new URL(window.location.href).searchParams.get("code");
  if (!code) {
    spotModal?.close();
    spotModal = null;
    return;
  }
  spotModal?.close();
  spotModal = await openSpotModal(code, () => {
    const url = new URL(window.location.href);
    url.searchParams.delete("code");
    window.history.replaceState({}, "", url);
  });
};

const render = () => {
  main.innerHTML = "";
  const url = new URL(window.location.href);
  currentRoute = parseRoute(url);

  if (currentRoute.kind === "checkin") {
    if (isCheckedIn()) {
      navigateToApp("/app", true);
      return;
    }
    root.replaceChildren(main);
    main.appendChild(
      renderCheckinPage({
        token: currentRoute.token,
        onComplete: () => navigateToApp("/app", true),
      }),
    );
    return;
  }

  if (!isCheckedIn()) {
    const token = url.searchParams.get("token") ?? undefined;
    if (token) {
      navigateToCheckin(token, true);
      return;
    }
    root.replaceChildren(main);
    main.appendChild(renderCheckinRequired());
    return;
  }

  const shell = createAppShell({
    currentPath: currentRoute.path,
    onNavigate: navigate,
  });
  const page =
    currentRoute.path === "/app/nearby"
      ? renderNearby()
      : currentRoute.path === "/app/events"
        ? renderEventsPage()
        : currentRoute.path === "/app/reserve"
          ? renderReserve()
          : currentRoute.path === "/app/status"
            ? renderStatus()
            : currentRoute.path === "/app/empty"
              ? renderEmptyStatePage()
              : renderHome({
                  checkinState,
                  onCodeSubmit: handleCodeOpen,
                  onNavigate: navigate,
                  onResetCheckin: () => {
                    clearCheckinProfile();
                    showToast({ message: "チェックイン情報をリセットしました", tone: "info" });
                    navigateToApp("/app", true);
                  },
                });

  const bottomNav = createBottomNav(currentRoute.path, navigate);

  root.replaceChildren(shell, main, bottomNav);
  main.appendChild(page);
  document.querySelectorAll<HTMLElement>(".md-ripple").forEach((el) => attachRipple(el));
  void openSpotFromUrl();
};

window.addEventListener("popstate", () => {
  render();
});

setupLogRetry();
render();
registerServiceWorker();

function registerServiceWorker() {
  if (isWebRuntime && "serviceWorker" in navigator) {
    navigator.serviceWorker.register("/sw.js").catch((err) => console.warn("sw registration failed", err));
  }
}

function enforceLightTheme() {
  document.documentElement.style.colorScheme = "light";
  document.documentElement.setAttribute("data-theme", "light");
  localStorage.setItem(THEME_STORAGE_KEY, "light");

  const media = window.matchMedia?.("(prefers-color-scheme: dark)");
  if (!media) return;
  const handler = () => {
    document.documentElement.style.colorScheme = "light";
    document.documentElement.setAttribute("data-theme", "light");
    localStorage.setItem(THEME_STORAGE_KEY, "light");
  };
  media.addEventListener("change", handler);
  handler();
}

function readCheckinState(): CheckinState {
  try {
    const raw = localStorage.getItem(CHECKIN_STORAGE_KEY);
    if (!raw) return { checkedIn: false };
    const parsed = JSON.parse(raw) as CheckinState;
    return { checkedIn: Boolean(parsed.checkedIn), code: parsed.code, checkedAt: parsed.checkedAt };
  } catch {
    return { checkedIn: false };
  }
}

function setCheckinState(code: string) {
  checkinState = {
    checkedIn: true,
    code,
    checkedAt: new Date().toISOString(),
  };
  localStorage.setItem(CHECKIN_STORAGE_KEY, JSON.stringify(checkinState));
}
