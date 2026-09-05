import { Navigate, Route, Routes } from 'react-router-dom';
import { RequireAuth } from './auth/RequireAuth';
import { Login } from './pages/Login';
import { Dashboard } from './pages/Dashboard';
import { CrowdAnalysis } from './pages/CrowdAnalysis';
import { QRIssue } from './pages/QRIssue';
import { Logs } from './pages/Logs';
import { Placeholder } from './pages/Placeholder';

export default function App() {
  return (
    <Routes>
      <Route path="/login" element={<Login />} />
      <Route element={<RequireAuth />}>
        <Route path="/" element={<Dashboard />} />
        <Route path="/spots" element={<CrowdAnalysis />} />
        <Route
          path="/events"
          element={<Placeholder title="Events" description="Event management page is under construction." />}
        />
        <Route
          path="/schedule"
          element={<Placeholder title="Schedule" description="Schedule management page is under construction." />}
        />
        <Route path="/qr" element={<QRIssue />} />
        <Route path="/logs" element={<Logs />} />
        <Route
          path="/settings"
          element={<Placeholder title="Settings" description="Settings page is under construction." />}
        />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Route>
    </Routes>
  );
}
