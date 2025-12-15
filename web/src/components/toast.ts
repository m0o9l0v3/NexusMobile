type ToastOptions = {
  message: string;
  tone?: "info" | "success" | "danger";
  durationMs?: number;
};

const containerId = "toast-container";

const ensureContainer = (): HTMLElement => {
  let container = document.getElementById(containerId);
  if (!container) {
    container = document.createElement("div");
    container.id = containerId;
    container.className = "toast-container";
    document.body.appendChild(container);
  }
  return container;
};

export const showToast = (options: ToastOptions): void => {
  const container = ensureContainer();
  const toast = document.createElement("div");
  toast.className = `toast toast--${options.tone ?? "info"} motion-soft`;
  toast.textContent = options.message;
  container.appendChild(toast);

  const duration = options.durationMs ?? 2800;
  setTimeout(() => {
    toast.classList.add("toast--hide");
    setTimeout(() => toast.remove(), 240);
  }, duration);
};

export const toastStyles = `
.toast-container {
  position: fixed;
  inset: auto var(--space-3) var(--space-4) var(--space-3);
  display: grid;
  gap: var(--space-2);
  z-index: 40;
}
.toast {
  padding: 12px 14px;
  border-radius: var(--radius);
  border: 1px solid var(--border);
  background: var(--surface);
  color: var(--text);
  box-shadow: var(--shadow);
}
.toast--success {
  border-color: var(--success);
}
.toast--danger {
  border-color: var(--danger);
}
.toast--hide {
  opacity: 0;
  transform: translateY(6px);
}
`;
