import { BrowserRouter, Routes, Route, Navigate, useLocation, useNavigate } from 'react-router-dom';
import { useEffect, useRef } from 'react';
import HomePage from './pages/HomePage';
import TentangPage from './pages/TentangPage';
import CaraPakaiPage from './pages/CaraPakaiPage';
import AuthPage from './pages/AuthPage';
import DashboardPage from './pages/DashboardPage';
import FormBuilderPage from './pages/FormBuilderPage';
import FormFillPage from './pages/FormFillPage';
import ProfilePage from './pages/ProfilePage';
import AiFormBuilderPage from './pages/AiFormBuilderPage';
import { getValidToken } from './utils/authStorage';

function PrivateRoute({ children }) {
  const token = getValidToken();
  const location = useLocation();

  if (!token) {
    const raw = location.pathname + location.search;
    const safe = raw.startsWith('/') && !raw.startsWith('//') ? raw : '/dashboard';
    const redirectUrl = encodeURIComponent(safe);
    return <Navigate to={`/auth?redirect=${redirectUrl}`} replace />;
  }

  return children;
}

function PublicRoute({ children }) {
  const token = getValidToken();
  // Jika sudah punya sesi valid (remember maupun session), jangan tampilkan /auth lagi.
  if (token) {
    return <Navigate to="/dashboard" replace />;
  }
  return children;
}

function AuthExpiredListener() {
  const navigate = useNavigate();
  const location = useLocation();
  const lastNavRef = useRef(0);
  useEffect(() => {
    const onExpired = () => {
      const now = Date.now();
      if (now - lastNavRef.current < 2000) return;
      const path = globalThis.location?.pathname || location.pathname;
      const publicPaths = ['/', '/tentang', '/cara-pakai', '/auth'];
      const isPublicFill = path.startsWith('/f/') || path.startsWith('/forms/public/');
      if (publicPaths.includes(path) || isPublicFill) return;
      if (path.startsWith('/auth')) return;
      lastNavRef.current = now;
      navigate('/auth?expired=1', { replace: true });
    };
    globalThis.addEventListener('auth:expired', onExpired);
    return () => globalThis.removeEventListener('auth:expired', onExpired);
  }, [navigate]);
  return null;
}

function App() {
  return (
    <BrowserRouter>
      <AuthExpiredListener />
      <Routes>
        <Route path="/" element={<HomePage />} />
        <Route path="/tentang" element={<TentangPage />} />
        <Route path="/cara-pakai" element={<CaraPakaiPage />} />
        <Route path="/auth" element={<PublicRoute><AuthPage /></PublicRoute>} />
        <Route
          path="/profile"
          element={
            <PrivateRoute>
              <ProfilePage />
            </PrivateRoute>
          }
        />
        <Route
          path="/dashboard"
          element={
            <PrivateRoute>
              <DashboardPage />
            </PrivateRoute>
          }
        />
        <Route
          path="/form-builder"
          element={
            <PrivateRoute>
              <FormBuilderPage />
            </PrivateRoute>
          }
        />
        <Route
          path="/form-builder/:formId"
          element={
            <PrivateRoute>
              <FormBuilderPage />
            </PrivateRoute>
          }
        />
        <Route
          path="/ai-builder"
          element={
            <PrivateRoute>
              <AiFormBuilderPage />
            </PrivateRoute>
          }
        />
        {/* Form Filler Routes — publik, boleh anonim (Google-Forms style).
            Proteksi login (jika form butuh login) ditangani di dalam FormFillPage. */}
        <Route path="/f/:slug" element={<FormFillPage />} />
        <Route path="/forms/public/:slug" element={<FormFillPage />} />
        {/* Fallback */}
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </BrowserRouter>
  );
}

export default App;
