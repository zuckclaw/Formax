import { Navigate, Route, Routes } from 'react-router-dom'
import { AuthProvider, useAuth } from './context/AuthContext'
import ProtectedRoute from './components/ProtectedRoute'
import LoginPage from './pages/LoginPage'
import RegisterPage from './pages/RegisterPage'
import DashboardPage from './pages/DashboardPage'
import FormBuilderPage from './pages/FormBuilderPage'
import TemplatesPage from './pages/TemplatesPage'
import HistoryPage from './pages/HistoryPage'
import CreateFormPage from './pages/CreateFormPage'
import CreateTemplatePage from './pages/CreateTemplatePage'
import EditFormPage from './pages/EditFormPage'
import FormResponsePage from './pages/FormResponsePage'
import FormResponsesPage from './pages/FormResponsesPage'
import ReportsPage from './pages/ReportsPage'
import HomePage from './pages/HomePage'
import TentangPage from './pages/TentangPage'
import CaraPakaiPage from './pages/CaraPakaiPage'
import PublicFormPage from './pages/PublicFormPage'
import ProfilePage from './pages/ProfilePage'
import './App.css'

const AppRoutes = () => {
  const { isAuthenticated } = useAuth()

  return (
    <Routes>
      <Route path="/" element={<HomePage />} />
      <Route path="/tentang" element={<TentangPage />} />
      <Route path="/cara-pakai" element={<CaraPakaiPage />} />
      <Route path="/login" element={isAuthenticated ? <Navigate to="/dashboard" replace /> : <LoginPage />} />
      <Route path="/register" element={isAuthenticated ? <Navigate to="/dashboard" replace /> : <RegisterPage />} />
      <Route
        path="/dashboard"
        element={
          <ProtectedRoute>
            <DashboardPage />
          </ProtectedRoute>
        }
      />
      <Route
        path="/templates"
        element={
          <ProtectedRoute>
            <TemplatesPage />
          </ProtectedRoute>
        }
      />
      <Route
        path="/history"
        element={
          <ProtectedRoute>
            <HistoryPage />
          </ProtectedRoute>
        }
      />
      <Route
        path="/forms/create"
        element={
          <ProtectedRoute>
            <Navigate to="/builder" replace />
          </ProtectedRoute>
        }
      />
      <Route
        path="/forms/public/:formId"
        element={
          <ProtectedRoute>
            <PublicFormPage />
          </ProtectedRoute>
        }
      />
      <Route
        path="/templates/create"
        element={
          <ProtectedRoute>
            <CreateTemplatePage />
          </ProtectedRoute>
        }
      />
      <Route
        path="/forms/:formId/edit"
        element={
          <ProtectedRoute>
            <Navigate to="/builder" replace />
          </ProtectedRoute>
        }
      />
      <Route
        path="/forms/:formId"
        element={
          <ProtectedRoute>
            <PublicFormPage />
          </ProtectedRoute>
        }
      />
      <Route
        path="/forms/:formId/responses"
        element={
          <ProtectedRoute>
            <FormResponsesPage />
          </ProtectedRoute>
        }
      />
      <Route
        path="/builder"
        element={
          <ProtectedRoute>
            <FormBuilderPage />
          </ProtectedRoute>
        }
      />
      <Route
        path="/reports"
        element={
          <ProtectedRoute>
            <ReportsPage />
          </ProtectedRoute>
        }
      />
      <Route
        path="/profile"
        element={
          <ProtectedRoute>
            <ProfilePage />
          </ProtectedRoute>
        }
      />
      <Route path="*" element={<Navigate to={isAuthenticated ? '/dashboard' : '/'} replace />} />
    </Routes>
  )
}

function App() {
  return (
    <AuthProvider>
      <AppRoutes />
    </AuthProvider>
  )
}

export default App
