import createClient from 'openapi-fetch';
import type { paths } from './schema';
import { clearAdminSession, getAdminToken } from '../auth/session';

export const baseUrl = import.meta.env.VITE_ADMIN_API_BASE_URL ?? 'http://localhost:5000';

export const authenticatedFetch: typeof fetch = async (input, init) => {
  // Preserve JSON headers/body for both URL + init and Request callers.
  const request = new Request(input, init);
  const isLogin = new URL(request.url).pathname.endsWith('/admin/auth/login');
  const token = isLogin ? null : getAdminToken();
  if (token) request.headers.set('Authorization', `Bearer ${token}`);
  else request.headers.delete('Authorization');
  const response = await fetch(request);
  if (!isLogin && token && response.status === 401) clearAdminSession(token);
  return response;
};

export const apiClient = createClient<paths>({ baseUrl, fetch: authenticatedFetch });
