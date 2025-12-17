type InputProps = {
  label: string;
  placeholder?: string;
  type?: string;
  name?: string;
  value?: string;
};

export const createInputField = (props: InputProps): HTMLElement => {
  const wrap = document.createElement("label");
  wrap.className = "field";
  const span = document.createElement("span");
  span.className = "field__label";
  span.textContent = props.label;
  const input = document.createElement("input");
  input.className = "field__input";
  input.type = props.type ?? "text";
  if (props.placeholder) input.placeholder = props.placeholder;
  if (props.name) input.name = props.name;
  if (props.value) input.value = props.value;
  wrap.append(span, input);
  return wrap;
};

export const inputFieldStyles = `
.field {
  display: grid;
  gap: 6px;
}
.field__label {
  font-weight: 700;
  color: var(--text);
  font-size: 0.95rem;
}
.field__input {
  padding: 12px 14px;
  border-radius: 14px;
  border: 1px solid var(--border);
  background: #fff;
  box-shadow: inset 0 1px 0 rgba(255,255,255,0.8);
}
.field__input:focus-visible {
  outline: none;
  box-shadow: var(--focus-ring);
}
`;
