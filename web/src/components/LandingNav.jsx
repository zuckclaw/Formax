import React from 'react';
import { Link } from 'react-router-dom';
import logoForm4x from '../assets/logo_form4x.png';
import ThemeToggle from './ThemeToggle';

export default function LandingNav({ active = 'beranda' }) {
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
          <Link to="/auth?mode=login" className="hp-btn-login">Login</Link>
          <Link to="/auth?mode=register" className="hp-btn-register">Daftar</Link>
        </div>
      </div>
    </header>
  );
}
