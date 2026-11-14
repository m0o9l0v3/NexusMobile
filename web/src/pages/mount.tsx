import { StrictMode, type ReactNode } from 'react';
import { createRoot } from 'react-dom/client';

export function mount(node: ReactNode) {
  createRoot(document.getElementById('root')!).render(<StrictMode>{node}</StrictMode>);
}
