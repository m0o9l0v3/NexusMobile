import { Navigate, Outlet, useLocation } from 'react-router-dom';
import { Layout } from '../components/Layout';
import { useAdminToken } from './useAdminToken';

export function RequireAuth() {
  const token = useAdminToken();
  const location = useLocation();
  if (!token) {
    return <Navigate to="/login" replace state={{ from: location.pathname + location.search + location.hash }} />;
  }
  return <Layout><Outlet /></Layout>;
}
