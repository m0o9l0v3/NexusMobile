import createClient from 'openapi-fetch';
import type { paths } from './schema';

export const baseUrl = import.meta.env.VITE_ADMIN_API_BASE_URL ?? 'http://localhost:5000';

export const apiClient = createClient<paths>({
  baseUrl,
  fetch: async (input, init) => {
    const token = localStorage.getItem('adminToken');
    const headers = new Headers(init?.headers);
    if (token) {
      headers.set('Authorization', `Bearer ${token}`);
    }
    return fetch(input, { ...init, headers });
  },
});
