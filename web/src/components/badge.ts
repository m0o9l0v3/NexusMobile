export const createBadge = (label: string, tone: "info" | "danger" | "success" = "info"): HTMLElement => {
  const badge = document.createElement("span");
  badge.className = `badge badge--${tone}`;
  badge.textContent = label;
  return badge;
};

export const badgeStyles = `
.badge {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 6px 10px;
  border-radius: 999px;
  font-weight: 700;
  font-size: 0.85rem;
  border: 1px solid var(--border);
  color: var(--text);
}
.badge--danger {
  border-color: var(--danger);
  color: var(--danger);
}
.badge--success {
  border-color: var(--success);
  color: var(--success);
}
`;
