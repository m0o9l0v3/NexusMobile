export const createCard = (title?: string, body?: HTMLElement | string): HTMLElement => {
  const card = document.createElement("article");
  card.className = "card surface glass motion-soft";
  if (title) {
    const heading = document.createElement("div");
    heading.className = "card__title row";
    heading.textContent = title;
    card.appendChild(heading);
  }
  if (body) {
    const wrapper = document.createElement("div");
    wrapper.className = "card__body";
    if (typeof body === "string") {
      wrapper.innerHTML = body;
    } else {
      wrapper.appendChild(body);
    }
    card.appendChild(wrapper);
  }
  return card;
};

export const cardStyles = `
.card {
  padding: var(--space-3);
  border-radius: var(--radius-lg);
  border: 1px solid var(--border);
  box-shadow: var(--shadow);
}
.card__title {
  font-weight: 700;
  color: var(--text);
  margin-bottom: var(--space-2);
}
.card__body {
  color: var(--text);
}
`;
