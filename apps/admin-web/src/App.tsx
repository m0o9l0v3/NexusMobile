import { Navigate, Route, Routes } from 'react-router-dom';
import { Layout } from './components/Layout';
import { Dashboard } from './pages/Dashboard';
import { CrowdAnalysis } from './pages/CrowdAnalysis';
import { QRIssue } from './pages/QRIssue';
import { Logs } from './pages/Logs';
import { Placeholder } from './pages/Placeholder';

export default function App() {
  return (
    <Layout>
      <Routes>
        <Route path="/" element={<Dashboard />} />
        <Route path="/spots" element={<CrowdAnalysis />} />
        <Route path="/events" element={<Placeholder title="イベント管理" description="イベント管理ページは準備中です。" />} />
        <Route
          path="/schedule"
          element={<Placeholder title="オープンキャンパス日程" description="日程管理ページは準備中です。" />}
        />
        <Route path="/qr" element={<QRIssue />} />
        <Route path="/logs" element={<Logs />} />
        <Route path="/settings" element={<Placeholder title="設定" description="システム設定ページは準備中です。" />} />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </Layout>
  );
}
