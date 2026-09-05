// This is only a client-side expiry check. Signature and revocation validation
// remain the responsibility of the Admin API.
export function tokenExpiresAt(token: string | null): number | null {
  if (!token) return null;
  try {
    const parts = token.split('.');
    if (parts.length !== 3 || parts.some((part) => !part)) return null;
    const payload = JSON.parse(atob(parts[1].replace(/-/g, '+').replace(/_/g, '/')));
    const expiresAt = payload.exp * 1000;
    return typeof payload.exp === 'number' && Number.isFinite(expiresAt) ? expiresAt : null;
  } catch {
    return null;
  }
}

export function returnPath(state: unknown): string {
  if (!state || typeof state !== 'object' || !('from' in state)) return '/';
  const from = state.from;
  if (typeof from !== 'string' || !from.startsWith('/') || from.startsWith('//') || /[\\\r\n]/.test(from)) return '/';
  // Only accept existing portal routes, never the login page or an external URL.
  const pathname = from.split(/[?#]/, 1)[0];
  return ['/', '/spots', '/events', '/schedule', '/qr', '/logs', '/settings'].includes(pathname) ? from : '/';
}
