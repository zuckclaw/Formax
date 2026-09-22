import { Link } from 'react-router-dom';
import logoForm4x from '../assets/logo_form4x.png';

const socialIconProps = {
  fill: 'none',
  viewBox: '0 0 24 24',
  stroke: 'currentColor',
  strokeWidth: 2,
  strokeLinecap: 'round',
  strokeLinejoin: 'round',
};

export default function LandingFooter() {
  return (
    <footer className="hp-footer">
      <div className="hp-footer-inner">
        <div className="hp-footer-main">
          <div className="hp-footer-brand-col">
            <Link to="/" className="hp-footer-logo">
              <img src={logoForm4x} alt="Form4x" />
              <span>Form4x</span>
            </Link>
            <p className="hp-footer-tagline">
              Tempat membuat Form Terlengkap &amp; Terpercaya — langsung dari browser.
            </p>
            <div className="hp-footer-socials">
              <a href="mailto:halo@form4x.id" aria-label="Email Form4x" title="Email">
                <svg {...socialIconProps}>
                  <rect x="2" y="4" width="20" height="16" rx="2" />
                  <path d="M22 7l-10 6L2 7" />
                </svg>
              </a>
              <a href="#" aria-label="Instagram Form4x" title="Instagram">
                <svg {...socialIconProps}>
                  <rect x="2" y="2" width="20" height="20" rx="5" />
                  <circle cx="12" cy="12" r="4" />
                  <line x1="17.5" y1="6.5" x2="17.5" y2="6.5" />
                </svg>
              </a>
              <a href="#" aria-label="X Form4x" title="X">
                <svg {...socialIconProps}>
                  <path d="M4 4l16 16M20 4L4 20" />
                </svg>
              </a>
              <a href="#" aria-label="GitHub Form4x" title="GitHub">
                <svg {...socialIconProps}>
                  <path d="M9 19c-5 1.5-5-2.5-7-3m14 6v-3.87a3.37 3.37 0 00-.94-2.61c3.14-.35 6.44-1.54 6.44-7A5.44 5.44 0 0020 4.77 5.07 5.07 0 0019.91 1S18.73.65 16 2.48a13.38 13.38 0 00-7 0C6.27.65 5.09 1 5.09 1A5.07 5.07 0 005 4.77a5.44 5.44 0 00-1.5 3.78c0 5.42 3.3 6.61 6.44 7A3.37 3.37 0 009 18.13V22" />
                </svg>
              </a>
            </div>
          </div>

          <nav className="hp-footer-navcols" aria-label="Footer">
            <div className="hp-footer-col">
              <h4>Navigasi</h4>
              <Link to="/">Beranda</Link>
              <Link to="/tentang">Tentang</Link>
              <Link to="/cara-pakai">Cara Pakai</Link>
            </div>
            <div className="hp-footer-col">
              <h4>Mulai</h4>
              <Link to="/auth">Masuk</Link>
              <Link to="/auth">Daftar Gratis</Link>
              <Link to="/dashboard">Dashboard</Link>
            </div>
          </nav>
        </div>

        <div className="hp-footer-divider" />
        <p className="hp-footer-copy">© 2026 Form4x. All rights reserved.</p>
      </div>
    </footer>
  );
}
