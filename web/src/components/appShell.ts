type ShellOptions = {
  onNavigate: (path: string) => void;
  currentPath: string;
  onCodeSubmit?: (code: string) => void;
  onRequestQr?: () => void;
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
  right.addEventListener("click", () => options.onNavigate("/events"));

  top.append(left, brand, right);

  const hero = document.createElement("section");
  hero.className = "app-hero";
  hero.innerHTML = `
    <div class="app-hero__title-row">
      <div class="app-hero__avatar"></div>
      <div class="app-hero__title">ゲストチェックイン</div>
    </div>
    <div class="app-hero__card">
      <div class="app-hero__subtitle">コード入力かQRでチェックイン</div>
      <div class="app-hero__actions">
        <button class="cta-button md-ripple" type="button" data-action="code">コードを入力する</button>
        <button class="cta-button secondary md-ripple" type="button" data-action="qr">QRを読み取る</button>
      </div>
    </div>
  `;

  const codeBtn = hero.querySelector<HTMLButtonElement>('[data-action="code"]');
  const qrBtn = hero.querySelector<HTMLButtonElement>('[data-action="qr"]');

  codeBtn?.addEventListener("click", () => {
    const code = prompt("スポットコードを入力してください");
    if (code) options.onCodeSubmit?.(code.trim());
  });
  qrBtn?.addEventListener("click", () => options.onRequestQr?.());

  header.append(top, hero);
  return header;
};

export const appShellStyles = `
.app-shell {
  position: sticky;
  top: 0;
  z-index: 10;
  display: grid;
  gap: 12px;
  padding: 14px 14px 16px;
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

/* Hero block */
.app-hero {
  display: grid;
  gap: 12px;
  padding: 12px;
  border-radius: 20px;
  background: rgba(255,255,255,0.75);
  box-shadow: 0 10px 30px rgba(12,52,140,0.08);
}
.app-hero__title-row {
  display: grid;
  grid-template-columns: auto 1fr;
  align-items: center;
  gap: 12px;
}
.app-hero__avatar {
  width: 52px;
  height: 52px;
  border-radius: 50%;
  background: radial-gradient(circle at 50% 40%, #7fb1ff 0%, #4a8bff 70%);
  box-shadow: inset 0 0 0 3px #ddebff;
}
.app-hero__title {
  font-weight: 800;
  color: #1c4b99;
  font-size: 1.05rem;
}
.app-hero__card {
  padding: 14px 14px 16px;
  border-radius: 18px;
  background: linear-gradient(180deg, #e7f1ff 0%, #f3f8ff 100%);
  box-shadow: inset 0 1px 0 rgba(255,255,255,0.7);
  display: grid;
  gap: 10px;
  text-align: center;
}
.app-hero__subtitle {
  color: #1c4b99;
  font-weight: 600;
}
.cta-button {
  border: none;
  padding: 12px 16px;
  border-radius: 999px;
  background: #ffffff;
  color: #0c348c;
  font-weight: 800;
  box-shadow: 0 8px 20px rgba(12,52,140,0.16);
}

@media (max-width: 720px) {
  .app-hero__title { font-size: 1rem; }
}
`;
