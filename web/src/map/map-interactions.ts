export function attachMapInteractions(
  viewport: HTMLElement,
  content: SVGGElement
) {
  let tx = 0, ty = 0, s = 1;
  let last: { x: number; y: number } | null = null;
  let startDist = 0;
  let startScale = 1;
  let pinchCenter: { x: number; y: number } | null = null;

  const apply = () => {
    content.setAttribute("transform", `translate(${tx}, ${ty}) scale(${s})`);
  };

  const dist = (a: Touch, b: Touch) =>
    Math.hypot(b.clientX - a.clientX, b.clientY - a.clientY);

  const center = (a: Touch, b: Touch) => ({
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
        startScale = s;
        pinchCenter = center(e.touches[0], e.touches[1]);
      }
    },
    { passive: false }
  );

  viewport.addEventListener(
    "touchmove",
    (e) => {
      e.preventDefault();

      if (e.touches.length === 1 && last) {
        const t = e.touches[0];
        tx += t.clientX - last.x;
        ty += t.clientY - last.y;
        last = { x: t.clientX, y: t.clientY };
        apply();
        return;
      }

      if (e.touches.length === 2 && pinchCenter) {
        const ratio = dist(e.touches[0], e.touches[1]) / startDist;
        const newScale = clamp(startScale * ratio, 0.5, 4);

        // ピンチ中心を固定する補正
        const k = newScale / s;
        tx = pinchCenter.x - k * (pinchCenter.x - tx);
        ty = pinchCenter.y - k * (pinchCenter.y - ty);

        s = newScale;
        apply();
      }
    },
    { passive: false }
  );

  viewport.addEventListener("touchend", () => {
    if (viewportTouches(viewport) === 0) last = null;
    if (viewportTouches(viewport) < 2) pinchCenter = null;
  });

  apply();
}

function clamp(v: number, min: number, max: number) {
  return Math.min(Math.max(v, min), max);
}

// iOS Safari対策で「touches」を直接取れないケースがあるので保険
function viewportTouches(el: HTMLElement): number {
  const anyEl = el as any;
  return anyEl?.touches?.length ?? 0;
}
