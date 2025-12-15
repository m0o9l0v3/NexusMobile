import "./styles/design-tokens.css";
import "./styles/base.css";
import { appShellStyles, createAppShell } from "./components/appShell";
import { badgeStyles } from "./components/badge";
import { buttonStyles } from "./components/button";
import { cardStyles } from "./components/card";
import { modalStyles } from "./components/modal";
import { ticketStyles } from "./components/ticketCard";
import { toastStyles, showToast } from "./components/toast";
import { startQrScan, type QrHandle } from "./lib/qr";
import { setupLogRetry } from "./lib/logger";
import { openSpotModal } from "./pages/spot";
import { renderHome } from "./pages/home";
import { renderNearby } from "./pages/nearby";
import { renderEventsPage } from "./pages/events";

type Route = "/" | "/nearby" | "/events";

const componentStyles = [
  appShellStyles,
  badgeStyles,
  buttonStyles,
  cardStyles,
  modalStyles,
  ticketStyles,
  toastStyles,
  `
  main {
    display: grid;
    gap: var(--space-3);
    margin-top: var(--space-3);
  }
  .home-hero {
    background: linear-gradient(135deg, rgba(74, 163, 255, 0.18), rgba(12, 52, 140, 0.12));
  }
  .hero-title { font-size: 1.6rem; font-weight: 800; }
  .search-card {
    display: grid;
    gap: 10px;
    padding: var(--space-3);
    border-radius: var(--radius-lg);
    border: 1px solid var(--border);
    box-shadow: var(--shadow);
  }
  .search-input {
    padding: 12px 14px;
    border-radius: 12px;
    border: 1px solid var(--border);
    width: 100%;
  }
  .quick-row { flex-wrap: wrap; }
  .event-card__title { font-weight: 700; font-size: 1rem; }
  .near-card__title { font-weight: 700; font-size: 1rem; }
  .near-card__distance { font-weight: 800; }
  .space-between { justify-content: space-between; }
  .spot__info { display: grid; gap: 12px; align-items: start; }
  .spot__image { border-radius: 14px; object-fit: cover; width: 100%; max-height: 200px; }
  @media (min-width: 640px) { .spot__info { grid-template-columns: 1fr 0.7fr; } }
  `,
].join("\n");

const style = document.createElement("style");
style.textContent = componentStyles;
document.head.appendChild(style);

const root = document.querySelector<HTMLDivElement>("#app");
if (!root) throw new Error("app container missing");

const THEME_KEY = "nexus-theme";
const prefersDark = window.matchMedia("(prefers-color-scheme: dark)");

const setTheme = (mode: "light" | "dark" | "auto") => {
  const theme = mode === "auto" ? (prefersDark.matches ? "dark" : "light") : mode;
  document.documentElement.dataset.theme = theme;
  localStorage.setItem(THEME_KEY, mode);
};

const savedTheme = (localStorage.getItem(THEME_KEY) as "light" | "dark" | "auto" | null) ?? "auto";
setTheme(savedTheme);

const sanitizeRoute = (path: string): Route => {
  if (path === "/nearby" || path === "/events") return path;
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
  hint.textContent = "カメラが使えない場合はコード手入力で開けます。";
  content.append(video, hint);

  const modal = document.createElement("div");
  modal.appendChild(content);
  const handle = createAppModal(modal, async () => {
    await qrHandle?.stop();
    qrHandle = null;
  });

  try {
    qrHandle = await startQrScan(
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
    onToggleTheme: () => {
      const next = document.documentElement.dataset.theme === "dark" ? "light" : "dark";
      setTheme(next as "light" | "dark");
    },
  });
  const page =
    currentRoute === "/nearby"
      ? renderNearby()
      : currentRoute === "/events"
        ? renderEventsPage()
        : renderHome({
            onCodeSubmit: handleCodeOpen,
            onNavigate: navigate,
            onRequestQr: openQrModal,
          });

  root.replaceChildren(shell, main);
  main.appendChild(page);
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
  if ("serviceWorker" in navigator) {
    navigator.serviceWorker
      .register("/sw.js")
      .catch((err) => console.warn("sw registration failed", err));
  }
}
