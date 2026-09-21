import { Link } from 'react-router-dom';
import logoForm4x from '../assets/logo_form4x.png';
import ThemeToggle from './ThemeToggle';
import useAuthStatus from '../hooks/useAuthStatus';

export default function LandingNav({ active = 'beranda' }) {
  // Auth state ASLI project (sama seperti PrivateRoute): getValidToken().
  // true untuk login session maupun remember-me; false setelah logout/expired.
  const isAuthenticated = useAuthStatus();
  return (
    <header className="hp-header">
      <div className="hp-header-inner">
        <Link to="/" className="hp-brand">
          <img src={logoForm4x} alt="Form4x Logo" className="hp-brand-logo" />
          <span className="hp-brand-text">Form4x</span>
        </Link>

        <nav className="hp-nav">
          <Link
            to="/"
            className={`hp-nav-link${active === 'beranda' ? ' hp-nav-active' : ''}`}
          >
            Beranda
          </Link>
          <Link
            to="/tentang"
            className={`hp-nav-link${active === 'tentang' ? ' hp-nav-active' : ''}`}
          >
            Tentang
          </Link>
          <Link
            to="/cara-pakai"
            className={`hp-nav-link${active === 'cara-pakai' ? ' hp-nav-active' : ''}`}
          >
            Cara Pakai
          </Link>
        </nav>

        <div className="hp-header-actions">
          <ThemeToggle />
          {isAuthenticated ? (
            <Link to="/dashboard" className="hp-btn-register">Dashboard</Link>
          ) : (
            <>
              <Link to="/auth" className="hp-btn-login">Login</Link>
              <Link to="/auth" className="hp-btn-register">Daftar</Link>
            </>
          )}
        </div>
      </div>
    </header>
  );
}
