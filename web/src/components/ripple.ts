export const attachRipple = (el: HTMLElement) => {
  el.classList.add("md-ripple");
  el.addEventListener("pointerdown", (e) => {
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;
    const rect = el.getBoundingClientRect();
    const ripple = document.createElement("span");
    ripple.className = "md-ripple__ink";
    const size = Math.max(rect.width, rect.height) * 1.2;
    ripple.style.width = `${size}px`;
    ripple.style.height = `${size}px`;
    ripple.style.left = `${e.clientX - rect.left - size / 2}px`;
    ripple.style.top = `${e.clientY - rect.top - size / 2}px`;
    el.appendChild(ripple);
    ripple.addEventListener("animationend", () => ripple.remove(), { once: true });
  });
};

export const rippleStyles = `
.md-ripple {
  position: relative;
  overflow: hidden;
  -webkit-tap-highlight-color: transparent;
}
.md-ripple__ink {
  position: absolute;
  border-radius: 999px;
  background: radial-gradient(circle, rgba(12, 52, 140, 0.22) 0%, rgba(12, 52, 140, 0.0) 70%);
  transform: scale(0);
  animation: md-ripple 520ms ease-out;
  pointer-events: none;
}
@keyframes md-ripple {
  0% { transform: scale(0); opacity: 0.0; }
  15% { opacity: 1; }
  100% { transform: scale(1); opacity: 0; }
}
@media (prefers-reduced-motion: reduce) {
  .md-ripple__ink { display: none; }
}
`;
