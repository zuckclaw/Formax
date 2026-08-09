import { useState } from 'react'
import { Link, useLocation } from 'react-router-dom'
import { useAuth } from '../context/AuthContext'

const MainLayout = ({ children, searchQuery, setSearchQuery, hideSearch = false }) => {
  const { user, logout } = useAuth()
  const location = useLocation()
  const [logoFailed, setLogoFailed] = useState(false)

  const isActive = (path) => location.pathname === path

  const userName = user?.full_name || user?.name || 'Gita Nur'

  return (
    <div className="main-layout">
      {/* Sidebar Kiri */}
      <aside className="app-sidebar">
        {/* Slot Logo di Pojok Kiri Atas */}
        <div className="logo-section">
          <div className="logo-container">
            {!logoFailed ? (
              <img
                src="/logo.png"
                alt="Form4x Logo"
                className="logo-img"
                onError={() => setLogoFailed(true)}
              />
            ) : (
              <div className="logo-badge">
                <svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                  <path d="M4 4H12V8H8V12H12V20H4V4Z" fill="#3B82F6"/>
                  <path d="M14 4H20V12H16V20H12V16H16V12H14V4Z" fill="#F43F5E"/>
                </svg>
                <span className="logo-badge-text">F4</span>
              </div>
            )}
          </div>
        </div>

        {/* Menu Navigasi */}
        <nav className="sidebar-nav">
          <Link to="/dashboard" className={`nav-link ${isActive('/dashboard') ? 'active' : ''}`}>
            <svg className="nav-icon" width="20" height="20" viewBox="0 0 24 24" fill="currentColor">
              <path d="M4 4h4v4H4V4zm6 0h4v4h-4V4zm6 0h4v4h-4V4M4 10h4v4H4v-4zm6 0h4v4h-4v-4zm6 0h4v4h-4v-4M4 16h4v4H4v-4zm6 0h4v4h-4v-4zm6 0h4v4h-4v-4z" />
            </svg>
            <span>Dashboard</span>
          </Link>

          <Link to="/templates" className={`nav-link ${isActive('/templates') ? 'active' : ''}`}>
            <svg className="nav-icon" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <rect x="3" y="3" width="18" height="18" rx="2" />
              <path d="M3 9h18M9 21V9" />
            </svg>
            <span>Template</span>
          </Link>

          <Link to="/history" className={`nav-link ${isActive('/history') ? 'active' : ''}`}>
            <svg className="nav-icon" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <circle cx="12" cy="12" r="9" />
              <polyline points="12 6 12 12 16 14" />
            </svg>
            <span>History</span>
          </Link>
        </nav>

        {/* Profil Pengguna di Bagian Bawah Kiri */}
        <div className="sidebar-profile">
          <div className="profile-info">
            <img
              src="https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=120&q=80"
              alt={userName}
              className="profile-avatar"
            />
            <span className="profile-name">{userName}</span>
          </div>
          <button className="profile-logout-btn" onClick={logout} title="Keluar">
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4" />
              <polyline points="16 17 21 12 16 7" />
              <line x1="21" y1="12" x2="9" y2="12" />
            </svg>
          </button>
        </div>
      </aside>

      {/* Area Konten Utama */}
      <div className="layout-body">
        {/* Top Header Bar */}
        <header className="app-topbar">
          <div className="brand-header">
            <h1 className="brand-title">Form4x</h1>
            <p className="brand-subtitle">Tempat membuat Form Terlengkap</p>
          </div>

          {!hideSearch && (
            <div className="search-box">
              <svg className="search-icon" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <circle cx="11" cy="11" r="8" />
                <line x1="21" y1="21" x2="16.65" y2="16.65" />
              </svg>
              <input
                type="text"
                placeholder="Search"
                value={searchQuery || ''}
                onChange={(e) => setSearchQuery && setSearchQuery(e.target.value)}
                className="search-input"
              />
            </div>
          )}
        </header>

        {/* Main Content Area */}
        <main className="app-main-content">
          {children}
        </main>
      </div>
    </div>
  )
}

export default MainLayout
