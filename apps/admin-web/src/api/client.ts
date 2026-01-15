import createClient from 'openapi-fetch';
import type { paths } from './schema';

export const baseUrl = import.meta.env.VITE_ADMIN_API_BASE_URL ?? 'http://localhost:5000';

export const apiClient = createClient<paths>({
  baseUrl,
  headers: () => {
    const token = localStorage.getItem('adminToken');
    return token ? { Authorization: `Bearer ${token}` } : {};
  },
});
