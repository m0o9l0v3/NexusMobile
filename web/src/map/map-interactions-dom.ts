type Point = { x: number; y: number };

export function attachMapInteractionsToElement(
  viewport: HTMLElement,
  content: HTMLElement
) {
  let tx = 0;
  let ty = 0;
  let scale = 1;

  let last: Point | null = null;
  let startDist = 0;
  let startScale = 1;
  let pinchCenter: Point | null = null;

  const apply = () => {
    // 原点は左上基準、拡大縮小の見え方を安定させる
    content.style.transformOrigin = "0 0";
    content.style.transform = `translate(${tx}px, ${ty}px) scale(${scale})`;
  };

  const dist = (a: Touch, b: Touch) =>
    Math.hypot(b.clientX - a.clientX, b.clientY - a.clientY);

  const center = (a: Touch, b: Touch): Point => ({
    x: (a.clientX + b.clientX) / 2,
    y: (a.clientY + b.clientY) / 2,
  });

  viewport.style.touchAction = "none";

  viewport.addEventListener(
    "touchstart",
    (e) => {
      if (e.touches.length === 1) {
        last = { x: e.touches[0].clientX, y: e.touches[0].clientY };
      } else if (e.touches.length === 2) {
        startDist = dist(e.touches[0], e.touches[1]);
        startScale = scale;
        pinchCenter = center(e.touches[0], e.touches[1]);
      }
    },
    { passive: false }
  );

  viewport.addEventListener(
    "touchmove",
    (e) => {
      e.preventDefault();

      // 1本指パン
      if (e.touches.length === 1 && last) {
        const t = e.touches[0];
        tx += t.clientX - last.x;
        ty += t.clientY - last.y;
        last = { x: t.clientX, y: t.clientY };
        apply();
        return;
      }

      // 2本指ピンチズーム（中心固定）
      if (e.touches.length === 2 && pinchCenter) {
        const ratio = dist(e.touches[0], e.touches[1]) / startDist;
        const newScale = clamp(startScale * ratio, 0.5, 4);

        const k = newScale / scale;
        tx = pinchCenter.x - k * (pinchCenter.x - tx);
        ty = pinchCenter.y - k * (pinchCenter.y - ty);

        scale = newScale;
        apply();
      }
    },
    { passive: false }
  );

  viewport.addEventListener("touchend", () => {
    if (eTouches(viewport) === 0) last = null;
    if (eTouches(viewport) < 2) pinchCenter = null;
  });

  apply();
}

function clamp(v: number, min: number, max: number) {
  return Math.min(Math.max(v, min), max);
}

// 保険（環境によっては取れないので）
function eTouches(_: HTMLElement) {
  return 0;
}
