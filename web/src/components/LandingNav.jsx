import { Link, useNavigate } from 'react-router-dom';
import logoForm4x from '../assets/logo_form4x.png';
import ThemeToggle from './ThemeToggle';
import { getValidToken } from '../utils/authStorage';

export default function LandingNav({ active = 'beranda' }) {
  const navigate = useNavigate()
  const handleAuthClick = (e, _path = '/auth') => {
    const token = getValidToken()
    const isRemembered = localStorage.getItem('auth_remember') === 'true'
    if (token && isRemembered) {
      e.preventDefault()
      navigate('/dashboard')
    }
  }
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
          <Link to="/auth" className="hp-btn-login" onClick={handleAuthClick}>Login</Link>
          <Link to="/auth" className="hp-btn-register" onClick={handleAuthClick}>Daftar</Link>
        </div>
      </div>
    </header>
  );
}
