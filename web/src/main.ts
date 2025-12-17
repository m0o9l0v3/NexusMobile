import "./styles/design-tokens.css";
import "./styles/base.css";
import { appShellStyles, createAppShell } from "./components/appShell";
import { badgeStyles } from "./components/badge";
import { buttonStyles } from "./components/button";
import { cardStyles } from "./components/card";
import { modalStyles } from "./components/modal";
import { ticketStyles } from "./components/ticketCard";
import { toastStyles, showToast } from "./components/toast";
import { bottomNavStyles, createBottomNav } from "./components/bottomNav";
import { segmentedStyles } from "./components/segmentedControl";
import { tabsStyles } from "./components/tabs";
import { listItemStyles } from "./components/listItem";
import { inputFieldStyles } from "./components/inputField";
import { emptyStateStyles } from "./components/emptyState";
import { attachRipple, rippleStyles } from "./components/ripple";
import { startQr, type QrHandle } from "./lib/qrService";
import { setupLogRetry } from "./lib/logger";
import { openSpotModal } from "./pages/spot";
import { renderHome } from "./pages/home";
import { renderNearby } from "./pages/nearby";
import { renderEventsPage } from "./pages/events";
import { renderReserve } from "./pages/reserve";
import { renderStatus } from "./pages/status";
import { renderEmptyStatePage } from "./pages/emptyStatePage";
import { isWebRuntime } from "./lib/runtime";

type Route = "/" | "/nearby" | "/events" | "/reserve" | "/status" | "/empty";

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
  `,
].join("\n");

const style = document.createElement("style");
style.textContent = componentStyles;
document.head.appendChild(style);

const root = document.querySelector<HTMLDivElement>("#app");
if (!root) throw new Error("app container missing");

const sanitizeRoute = (path: string): Route => {
  if (path === "/nearby" || path === "/events" || path === "/reserve" || path === "/status" || path === "/empty") return path;
  return "/";
};

let currentRoute: Route = sanitizeRoute(window.location.pathname);
let spotModal: Awaited<ReturnType<typeof openSpotModal>> | null = null;
let qrHandle: QrHandle | null = null;

const main = document.createElement("main");

const navigate = (path: string) => {
  const safe = sanitizeRoute(path);
  const url = new URL(window.location.href);
  url.pathname = safe;
  if (safe !== "/") url.search = "";
  window.history.pushState({}, "", url);
  currentRoute = safe;
  render();
};

const handleCodeOpen = (code: string) => {
  const url = new URL(window.location.href);
  url.searchParams.set("code", code);
  window.history.pushState({}, "", url);
  void openSpotFromUrl();
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

const openQrModal = async () => {
  const content = document.createElement("div");
  content.className = "grid";
  const video = document.createElement("video");
  video.setAttribute("playsinline", "true");
  video.style.width = "100%";
  video.style.borderRadius = "14px";
  const hint = document.createElement("p");
  hint.className = "muted";
  hint.textContent = "カメラが使えない場合はコード手入力をご利用ください。";
  content.append(video, hint);

  const modal = document.createElement("div");
  modal.appendChild(content);
  const handle = createAppModal(modal, async () => {
    await qrHandle?.stop();
    qrHandle = null;
  });

  try {
    qrHandle = await startQr(
      video,
      (text) => {
        const code = extractCode(text);
        if (code) {
          showToast({ message: `${code} を読み取りました`, tone: "success" });
          handle.close();
          handleCodeOpen(code);
        } else {
          showToast({ message: "コードを判読できませんでした", tone: "danger" });
        }
      },
      (reason) => showToast({ message: reason, tone: "danger" }),
    );
  } catch (err) {
    console.error(err);
    showToast({ message: "スキャンを開始できませんでした", tone: "danger" });
  }
};

const createAppModal = (node: HTMLElement, onClose?: () => void) => {
  const overlay = document.createElement("div");
  overlay.className = "modal__overlay";
  const dialog = document.createElement("div");
  dialog.className = "modal glass surface";
  const close = document.createElement("button");
  close.className = "modal__close";
  close.textContent = "×";
  close.addEventListener("click", () => {
    overlay.remove();
    onClose?.();
  });
  overlay.addEventListener("click", (e) => {
    if (e.target === overlay) {
      overlay.remove();
      onClose?.();
    }
  });
  dialog.append(node, close);
  overlay.appendChild(dialog);
  document.body.appendChild(overlay);
  return { close: () => overlay.remove(), element: overlay };
};

const render = () => {
  main.innerHTML = "";
  const shell = createAppShell({
    currentPath: currentRoute,
    onNavigate: navigate,
  });
  const page =
    currentRoute === "/nearby"
      ? renderNearby()
      : currentRoute === "/events"
        ? renderEventsPage()
        : currentRoute === "/reserve"
          ? renderReserve()
          : currentRoute === "/status"
            ? renderStatus()
            : currentRoute === "/empty"
              ? renderEmptyStatePage()
              : renderHome({
                  onCodeSubmit: handleCodeOpen,
                  onNavigate: navigate,
                  onRequestQr: openQrModal,
                });

  const bottomNav = createBottomNav(currentRoute, navigate);

  root.replaceChildren(shell, main, bottomNav);
  main.appendChild(page);
  document.querySelectorAll<HTMLElement>(".md-ripple").forEach((el) => attachRipple(el));
  void openSpotFromUrl();
};

window.addEventListener("popstate", () => {
  currentRoute = sanitizeRoute(window.location.pathname);
  render();
});

setupLogRetry();
render();
registerServiceWorker();

function extractCode(text: string): string | null {
  const fromUrl = text.match(/code=([A-Za-z0-9_-]+)/);
  if (fromUrl?.[1]) return fromUrl[1];
  if (/^[A-Za-z0-9]{3,8}$/.test(text)) return text;
  return null;
}

function registerServiceWorker() {
  if (isWebRuntime && "serviceWorker" in navigator) {
    navigator.serviceWorker.register("/sw.js").catch((err) => console.warn("sw registration failed", err));
  }
}
