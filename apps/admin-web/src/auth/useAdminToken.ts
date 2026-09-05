import { useSyncExternalStore } from 'react';
import { getAdminToken, subscribeToSession } from './session';

export function useAdminToken() {
  return useSyncExternalStore(subscribeToSession, getAdminToken, () => null);
}
