export type ModalHandle = {
  close: () => void;
  element: HTMLElement;
};

export const createModal = (content: HTMLElement, onClose?: () => void): ModalHandle => {
  const overlay = document.createElement("div");
  overlay.className = "modal__overlay";

  const dialog = document.createElement("div");
  dialog.className = "modal glass surface";
  dialog.setAttribute("role", "dialog");
  dialog.appendChild(content);

  const closeBtn = document.createElement("button");
  closeBtn.className = "modal__close";
  closeBtn.innerHTML = "×";
  closeBtn.addEventListener("click", () => {
    overlay.remove();
    onClose?.();
  });

  overlay.addEventListener("click", (e) => {
    if (e.target === overlay) {
      overlay.remove();
      onClose?.();
    }
  });

  dialog.appendChild(closeBtn);
  overlay.appendChild(dialog);

  document.body.appendChild(overlay);

  return { element: overlay, close: () => overlay.remove() };
};

export const modalStyles = `
.modal__overlay {
  position: fixed;
  inset: 0;
  background: rgba(0, 0, 0, 0.35);
  display: grid;
  place-items: center;
  padding: 20px;
  z-index: 30;
}
.modal {
  position: relative;
  width: min(640px, 100%);
  padding: var(--space-4);
  border-radius: var(--radius-lg);
  box-shadow: var(--shadow);
}
.modal__close {
  position: absolute;
  top: 12px;
  right: 12px;
  background: var(--surface-2);
  border-radius: 50%;
  width: 36px;
  height: 36px;
  color: var(--text);
  font-size: 20px;
}
`;
