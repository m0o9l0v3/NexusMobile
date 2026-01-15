import { Navigate, Route, Routes } from 'react-router-dom';
import { ProtectedRoute } from './components/ProtectedRoute';
import { Layout } from './components/Layout';
import { LoginPage } from './pages/LoginPage';
import { DashboardPage } from './pages/DashboardPage';
import { SpotsPage } from './pages/spots/SpotsPage';
import { SpotDetailPage } from './pages/spots/SpotDetailPage';
import { SpotFormPage } from './pages/spots/SpotFormPage';
import { EventsPage } from './pages/events/EventsPage';
import { EventFormPage } from './pages/events/EventFormPage';
import { OcDaysPage } from './pages/ocdays/OcDaysPage';
import { LogsPage } from './pages/LogsPage';

export default function App() {
  return (
    <Routes>
      <Route path="/login" element={<LoginPage />} />
      <Route
        path="/"
        element={
          <ProtectedRoute>
            <Layout>
              <DashboardPage />
            </Layout>
          </ProtectedRoute>
        }
      />
      <Route
        path="/spots"
        element={
          <ProtectedRoute>
            <Layout>
              <SpotsPage />
            </Layout>
          </ProtectedRoute>
        }
      />
      <Route
        path="/spots/new"
        element={
          <ProtectedRoute>
            <Layout>
              <SpotFormPage />
            </Layout>
          </ProtectedRoute>
        }
      />
      <Route
        path="/spots/:id"
        element={
          <ProtectedRoute>
            <Layout>
              <SpotDetailPage />
            </Layout>
          </ProtectedRoute>
        }
      />
      <Route
        path="/spots/:id/edit"
        element={
          <ProtectedRoute>
            <Layout>
              <SpotFormPage />
            </Layout>
          </ProtectedRoute>
        }
      />
      <Route
        path="/events"
        element={
          <ProtectedRoute>
            <Layout>
              <EventsPage />
            </Layout>
          </ProtectedRoute>
        }
      />
      <Route
        path="/events/new"
        element={
          <ProtectedRoute>
            <Layout>
              <EventFormPage />
            </Layout>
          </ProtectedRoute>
        }
      />
      <Route
        path="/events/:id/edit"
        element={
          <ProtectedRoute>
            <Layout>
              <EventFormPage />
            </Layout>
          </ProtectedRoute>
        }
      />
      <Route
        path="/oc-days"
        element={
          <ProtectedRoute>
            <Layout>
              <OcDaysPage />
            </Layout>
          </ProtectedRoute>
        }
      />
      <Route
        path="/logs"
        element={
          <ProtectedRoute>
            <Layout>
              <LogsPage />
            </Layout>
          </ProtectedRoute>
        }
      />
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  );
}
