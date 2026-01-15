import { createButton } from "../components/button";
import { createCard } from "../components/card";
import { showToast } from "../components/toast";
import { getTodayEvents } from "../lib/api";
import { logEvent } from "../lib/logger";
import type { EventItem } from "../types";

type HomeOptions = {
  onCodeSubmit: (code: string) => void;
  onNavigate: (path: string) => void;
  onRequestQr: () => void;
  checkinState: {
    checkedIn: boolean;
    code?: string;
    checkedAt?: string;
  };
};

const quickActions = [
  { label: "現在地", icon: "📍", path: "/nearby" },
  { label: "イベント", icon: "🎫", path: "/events" },
  { label: "手入力", icon: "⌨️", path: "/" },
  { label: "チェックイン", icon: "🛫", path: "/nearby" },
  { label: "ヘルプ", icon: "❔", path: "/" },
];

const featuredCards = [
  {
    title: "受付・案内ブース",
    tag: "NXS01",
    bg: "linear-gradient(135deg, rgba(74,163,255,0.22), rgba(12,52,140,0.12))",
  },
  {
    title: "学生展示ツアー",
    tag: "OC22",
    bg: "linear-gradient(135deg, rgba(255,255,255,0.9), rgba(212,232,255,0.8))",
  },
  {
    title: "カフェテラス",
    tag: "CAFE",
    bg: "linear-gradient(135deg, rgba(255,250,230,0.85), rgba(255,240,210,0.7))",
  },
];

export const renderHome = (options: HomeOptions): HTMLElement => {
  const page = document.createElement("div");
  page.className = "grid home";

  const checkinSection = options.checkinState.checkedIn ? buildCheckinStatus(options) : buildHero(options);
  page.append(checkinSection, buildFeatured(options), buildQuickActions(options), buildEvents(options));
  return page;
};

const buildHero = (options: HomeOptions): HTMLElement => {
  const hero = document.createElement("div");
  hero.className = "hero-panel glass";

  const titleRow = document.createElement("div");
  titleRow.className = "row";
  const avatar = document.createElement("div");
  avatar.className = "hero-avatar";
  const titleText = document.createElement("div");
  titleText.innerHTML = `<div class="hero-title">ゲストチェックイン</div><div class="muted">ログイン不要で参加できます</div>`;
  titleRow.append(avatar, titleText);

  const cta = createButton({
    label: "コードを入力する",
    variant: "primary",
    onClick: () => {
      const code = prompt("スポットコードを入力してください");
      if (code) {
        options.onCodeSubmit(code.trim());
        showToast({ message: `${code} を開いています`, tone: "info" });
      }
    },
  });

  const subCta = createButton({
    label: "QRで読み取る",
    variant: "secondary",
    onClick: () => {
      options.onRequestQr();
      logEvent({ type: "qr_scan" });
    },
  });

  hero.append(titleRow, cta, subCta);
  return hero;
};

const buildCheckinStatus = (options: HomeOptions): HTMLElement => {
  const panel = document.createElement("div");
  panel.className = "status-panel glass";

  const row = document.createElement("div");
  row.className = "status-panel__row";
  const label = document.createElement("div");
  label.innerHTML = `<div class="section-title">チェックイン状況</div><div class="status-meta">次の案内を確認してください</div>`;
  const chip = document.createElement("span");
  chip.className = "status-chip";
  chip.textContent = "チェックイン済";
  row.append(label, chip);

  const codeLine = document.createElement("div");
  codeLine.className = "status-meta";
  codeLine.textContent = options.checkinState.code ? `受付コード: ${options.checkinState.code}` : "受付コードを保存しました";

  const action = createButton({
    label: "ステータスを見る",
    variant: "secondary",
    onClick: () => options.onNavigate("/status"),
  });
  action.classList.add("btn-small");

  panel.append(row, codeLine, action);
  return panel;
};

const buildFeatured = (options: HomeOptions): HTMLElement => {
  const wrap = document.createElement("section");
  wrap.className = "grid";

  const header = document.createElement("div");
  header.className = "section-header";
  header.innerHTML = `<div><div class="section-title">あなたへのおすすめ</div><div class="muted small">スポットにタップで移動します</div></div>`;
  const seeAll = createButton({
    label: "すべて見る",
    variant: "secondary",
    onClick: () => options.onNavigate("/events"),
  });
  seeAll.classList.add("btn-small");
  header.appendChild(seeAll);

  const scroller = document.createElement("div");
  scroller.className = "scroll-x";
  featuredCards.forEach((card) => {
    const item = createCard();
    item.classList.add("featured-card");
    item.classList.add("md-ripple");
    item.style.background = card.bg;
    item.innerHTML = `
      <div class="chip">${card.tag}</div>
      <div class="featured-title">${card.title}</div>
    `;
    item.addEventListener("click", () => options.onCodeSubmit(card.tag));
    scroller.appendChild(item);
  });

  wrap.append(header, scroller);
  return wrap;
};

const buildQuickActions = (options: HomeOptions): HTMLElement => {
  const wrap = document.createElement("section");
  wrap.className = "grid";
  const header = document.createElement("div");
  header.className = "section-header";
  header.innerHTML = `<div class="section-title">クイックアクセス</div>`;
  wrap.appendChild(header);

  const list = document.createElement("div");
  list.className = "quick-actions";
  quickActions.forEach((action) => {
    const btn = document.createElement("button");
    btn.className = "quick-btn surface md-ripple";
    btn.innerHTML = `<span class="quick-icon">${action.icon}</span><span class="quick-label">${action.label}</span>`;
    btn.addEventListener("click", () => options.onNavigate(action.path));
    list.appendChild(btn);
  });
  wrap.appendChild(list);
  return wrap;
};

const buildEvents = (options: HomeOptions): HTMLElement => {
  const wrap = document.createElement("section");
  wrap.className = "grid";
  const header = document.createElement("div");
  header.className = "section-header";
  header.innerHTML = `<div class="section-title">今日のイベント</div>`;
  const favorites = createButton({ label: "お気に入り", variant: "secondary", onClick: () => options.onNavigate("/events") });
  favorites.classList.add("btn-small");
  header.appendChild(favorites);

  const list = document.createElement("div");
  list.className = "grid";
  list.appendChild(createSkeleton());

  void getTodayEvents()
    .then((evts) => {
      list.innerHTML = "";
      if (!evts.length) {
        list.textContent = "本日のイベント情報は準備中です。";
        return;
      }
      evts.forEach((evt) => list.appendChild(renderEventCard(evt, options)));
    })
    .catch(() => {
      list.textContent = "取得に失敗しました。後ほどお試しください。";
    });

  wrap.append(header, list);
  return wrap;
};

const renderEventCard = (evt: EventItem, options: HomeOptions): HTMLElement => {
  const card = createCard();
  card.classList.add("event-card");
  card.innerHTML = `
    <div class="row space-between">
      <div>
        <div class="muted tabular small">${evt.start} - ${evt.end}</div>
        <div class="event-card__title">${evt.title}</div>
        <div class="muted small">${evt.location}</div>
      </div>
      <div class="chip">${evt.spotCode ?? "SPOT"}</div>
    </div>
  `;
  card.addEventListener("click", () => options.onCodeSubmit(evt.spotCode ?? ""));
  return card;
};

const createSkeleton = (): HTMLElement => {
  const block = document.createElement("div");
  block.className = "skeleton";
  block.style.height = "92px";
  block.style.borderRadius = "16px";
  return block;
};
