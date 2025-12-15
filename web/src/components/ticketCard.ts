type TicketProps = {
  code: string;
  title: string;
  subtitle?: string;
  footer?: string;
  muted?: string;
};

export const createTicketCard = (props: TicketProps): HTMLElement => {
  const ticket = document.createElement("article");
  ticket.className = "ticket motion-soft";

  const left = document.createElement("div");
  left.className = "ticket__main";
  left.innerHTML = `
    <div class="ticket__code tabular">${props.code}</div>
    <div class="ticket__title">${props.title}</div>
    ${props.subtitle ? `<div class="ticket__subtitle">${props.subtitle}</div>` : ""}
    ${props.muted ? `<div class="ticket__muted">${props.muted}</div>` : ""}
  `;

  const right = document.createElement("div");
  right.className = "ticket__stub";
  right.innerHTML = `
    <div class="ticket__barcode" aria-hidden="true"></div>
    ${props.footer ? `<div class="ticket__footer tabular">${props.footer}</div>` : ""}
  `;

  ticket.append(left, right);
  return ticket;
};

export const ticketStyles = `
.ticket {
  display: grid;
  grid-template-columns: 1fr 0.48fr;
  background: var(--surface);
  border: 1px dashed var(--border);
  border-radius: 18px;
  position: relative;
  overflow: hidden;
  box-shadow: var(--shadow);
}
.ticket::before,
.ticket::after {
  content: "";
  position: absolute;
  width: 26px;
  height: 26px;
  background: radial-gradient(circle at center, transparent 60%, var(--bg) 62%);
  top: 50%;
  transform: translateY(-50%);
  pointer-events: none;
}
.ticket::before { left: -13px; }
.ticket::after { right: -13px; }
.ticket__main {
  padding: var(--space-3);
  background: linear-gradient(135deg, var(--surface), var(--surface-tint));
}
.ticket__stub {
  padding: var(--space-3);
  background: linear-gradient(135deg, rgba(74, 163, 255, 0.12), rgba(12, 52, 140, 0.12));
  display: grid;
  align-content: space-between;
  border-left: 1px dashed var(--border);
}
.ticket__code {
  font-size: 1.4rem;
  font-weight: 800;
  letter-spacing: 0.18em;
}
.ticket__title {
  font-weight: 700;
  margin: 6px 0;
}
.ticket__subtitle {
  color: var(--text);
  font-weight: 600;
}
.ticket__muted {
  color: var(--muted);
  font-size: 0.92rem;
}
.ticket__barcode {
  height: 38px;
  background: repeating-linear-gradient(
    90deg,
    var(--text) 0px,
    var(--text) 2px,
    transparent 3px,
    transparent 5px
  );
  border-radius: 4px;
  opacity: 0.66;
}
.ticket__footer {
  font-weight: 700;
  text-align: right;
  color: var(--text);
}
@media (prefers-reduced-motion: reduce) {
  .ticket { clip-path: none; }
}
@media (max-width: 640px) {
  .ticket {
    grid-template-columns: 1fr;
  }
  .ticket__stub {
    border-left: none;
    border-top: 1px dashed var(--border);
  }
}
`;
