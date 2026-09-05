import { queryClient } from '../api/queryClient';
import { tokenExpiresAt } from './token';

const storageKey = 'adminToken';
const changeEvent = 'nexus:admin-session-change';
let invalidatedToken: string | null = null;

function storedToken(): string | null {
  try {
    return localStorage.getItem(storageKey);
  } catch {
    return null;
  }
}

export function getAdminToken(): string | null {
  const token = storedToken();
  const expiresAt = tokenExpiresAt(token);
  return token !== invalidatedToken && expiresAt !== null && expiresAt > Date.now() ? token : null;
}

export function setAdminToken(token: string) {
  const expiresAt = tokenExpiresAt(token);
  if (expiresAt === null || expiresAt <= Date.now()) throw new Error('Invalid admin session');
  // Keep the existing storage contract; its replacement belongs to Issue #56.
  localStorage.setItem(storageKey, token);
  invalidatedToken = null;
  queryClient.clear();
  window.dispatchEvent(new Event(changeEvent));
}

export function clearAdminSession(expectedToken?: string) {
  // An old in-flight request must not log out a newer session.
  if (expectedToken && storedToken() !== expectedToken) return;
  invalidatedToken = storedToken();
  try {
    localStorage.removeItem(storageKey);
  } catch {
    // Deny the token in memory even when browser storage becomes unavailable.
  }
  queryClient.clear();
  window.dispatchEvent(new Event(changeEvent));
}

export function subscribeToSession(onChange: () => void) {
  let timer: ReturnType<typeof setTimeout> | undefined;
  let previousToken = storedToken();
  const update = () => {
    clearTimeout(timer);
    const currentToken = storedToken();
    if (currentToken !== previousToken) {
      queryClient.clear();
      previousToken = currentToken;
    }
    const expiresAt = tokenExpiresAt(currentToken);
    if (currentToken && (!getAdminToken() || expiresAt === null)) {
      if (currentToken !== invalidatedToken) clearAdminSession();
      else onChange();
      return;
    }
    if (expiresAt !== null) {
      timer = setTimeout(update, Math.min(expiresAt - Date.now(), 2_147_483_647));
    }
    onChange();
  };
  const onStorage = (event: StorageEvent) => {
    if (event.key === storageKey || event.key === null) update();
  };
  window.addEventListener(changeEvent, update);
  window.addEventListener('storage', onStorage);
  window.addEventListener('focus', update);
  update();
  return () => {
    clearTimeout(timer);
    window.removeEventListener(changeEvent, update);
    window.removeEventListener('storage', onStorage);
    window.removeEventListener('focus', update);
  };
}
