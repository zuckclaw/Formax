import { Link, useNavigate } from 'react-router-dom';
import logoForm4x from '../assets/logo_form4x.png';
import ThemeToggle from '../components/ThemeToggle';
import InteractiveCubeBackground from '../components/InteractiveCubeBackground';
import LandingNav from '../components/LandingNav';
import { getValidToken } from '../utils/authStorage';
import '../styles/landing.css';

/* ─── Feature Card Component ─── */
function FeatureCard({ icon, title, desc }) {
  return (
    <div className="hp-feat-card">
      <div className="hp-feat-icon">{icon}</div>
      <h3 className="hp-feat-title">{title}</h3>
      <p className="hp-feat-desc">{desc}</p>
    </div>
  );
}

/* ─── Main HomePage ─── */
const HomePage = () => {
  const navigate = useNavigate()
  const handleCtaClick = (e) => {
    const token = getValidToken()
    const isRemembered = localStorage.getItem('auth_remember') === 'true'
    if (token && isRemembered) {
      e.preventDefault()
      navigate('/dashboard')
    }
  }
  const features = [
    {
      icon: (
        <svg width="24" height="24" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
          <path strokeLinecap="round" strokeLinejoin="round" d="M9.813 15.904L9 18.75l-.813-2.846a4.5 4.5 0 00-3.09-3.09L2.25 12l2.846-.813a4.5 4.5 0 003.09-3.09L9 5.25l.813 2.846a4.5 4.5 0 003.09 3.09L15.75 12l-2.846.813a4.5 4.5 0 00-3.09 3.09zM18.259 8.715L18 9.75l-.259-1.035a3.375 3.375 0 00-2.455-2.456L14.25 6l1.036-.259a3.375 3.375 0 002.455-2.456L18 2.25l.259 1.035a3.375 3.375 0 002.456 2.456L21.75 6l-1.035.259a3.375 3.375 0 00-2.456 2.456z" />
        </svg>
      ),
      title: 'Formax AI Builder',
      desc: 'Buat form, kuis, dan ujian cerdas secara otomatis dalam hitungan detik menggunakan AI & formula LaTeX.',
    },
    {
      icon: (
        <svg width="24" height="24" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
          <path strokeLinecap="round" strokeLinejoin="round" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
        </svg>
      ),
      title: 'Import Soal Word (.docx)',
      desc: 'Unggah file Word (.docx) untuk mengimpor puluhan soal sekaligus secara otomatis tanpa mengetik manual.',
    },
    {
      icon: (
        <svg width="24" height="24" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
          <circle cx="12" cy="12" r="10" />
          <polyline points="12 6 12 12 16 14" />
        </svg>
      ),
      title: 'Timer & Auto-Submit',
      desc: 'Batasi durasi pengerjaan dengan timer presisi yang otomatis mengumpulkan jawaban saat waktu habis.',
    },
    {
      icon: (
        <svg width="24" height="24" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
          <rect x="3" y="11" width="18" height="11" rx="2" ry="2" />
          <path d="M7 11V7a5 5 0 0110 0v4" />
        </svg>
      ),
      title: 'Mode Fullscreen Ujian',
      desc: 'Fitur keamanan pengawas ujian dengan pengacak soal, pengacak opsi, dan mode fullscreen wajib.',
    },
    {
      icon: (
        <svg width="24" height="24" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
          <path strokeLinecap="round" strokeLinejoin="round" d="M12 4v1m6 11h2m-6 0h-2v4m0-4v-3m0 0h3m-3 0h-3m-2-5h4m-4 0v4m0-4V7m14 4v4m0 0h-3m3 0v3m-3-3h-3m3-3V7m-7 4h.01M7 4h10" />
        </svg>
      ),
      title: 'Kode QR & Link Unik',
      desc: 'Setiap form memiliki Kode QR instan dan tautan unik untuk dibagikan tanpa perlu instalasi aplikasi.',
    },
    {
      icon: (
        <svg width="24" height="24" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
          <path strokeLinecap="round" strokeLinejoin="round" d="M9 17v-2m3 2v-4m3 4v-6m2 10H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
        </svg>
      ),
      title: 'Export ke Spreadsheet',
      desc: 'Rekap jawaban tersimpan rapi dan dapat diekspor langsung ke spreadsheet/Excel untuk analisis data.',
    },
  ];

  return (
    <div className="hp-root" style={{ position: 'relative' }}>
      <InteractiveCubeBackground />
      {/* ── NAVBAR ── */}
      <LandingNav active="beranda" />

      {/* ── HERO ── */}
      <section id="beranda" className="hp-hero">
        <div className="hp-hero-inner">
          <h1 className="hp-hero-title">
            Buat Form Anda <span className="hp-hero-accent">dengan Mudah</span>
          </h1>
          <p className="hp-hero-sub">
            Tingkatkan produktivitas dengan platform pembuatan form profesional.
            Dilengkapi dengan timer terintegrasi, pembuatan kode QR instan, dan
            sinkronisasi otomatis ke spreadsheet.
          </p>
          <div className="hp-hero-actions">
            <Link to="/auth" id="btn-daftar-gratis" className="hp-btn-primary" onClick={handleCtaClick}>
              Daftar Gratis
            </Link>
            <Link to="/tentang" className="hp-btn-outline">
              Pelajari Lebih Lanjut
            </Link>
          </div>

          {/* App Preview Mockup Container */}
          <div className="hp-mockup-wrap">
            <div className="hp-mockup-bar">
              <div className="hp-mockup-dots">
                <span className="hp-dot red" />
                <span className="hp-dot yellow" />
                <span className="hp-dot green" />
              </div>
              <div className="hp-mockup-address">https://form4x.app/dashboard</div>
            </div>
            <img
              src="/images/Dashboard.png"
              alt="Form4x Dashboard Preview"
              className="hp-mockup-img"
            />
          </div>
        </div>
      </section>

      {/* ── FEATURES ── */}
      <section id="fitur" className="hp-features">
        <div className="hp-section-inner">
          <div className="hp-section-header">
            <span className="hp-section-tag">KEUNGGULAN UTAMA</span>
            <h2 className="hp-section-title">Fitur Canggih</h2>
            <p className="hp-section-desc">
              Didesain khusus untuk memenuhi kebutuhan survei, ujian online, pendaftaran event, dan pengumpulan data secara real-time.
            </p>
          </div>
          <div className="hp-feat-grid">
            {features.map((f, i) => (
              <FeatureCard key={i} {...f} />
            ))}
          </div>
        </div>
      </section>

      {/* ── PLATFORMS ── */}
      <section id="tentang" className="hp-platforms">
        <div className="hp-section-inner">
          <div className="hp-section-header">
            <span className="hp-section-tag">LINTAS PERANGKAT</span>
            <h2 className="hp-section-title">Tersedia Di Mana Saja</h2>
            <p className="hp-section-desc">
              Akses borang dan kelola respons Anda kapan saja dari perangkat apa pun.
            </p>
          </div>
          <div className="hp-platform-row">
            <div className="hp-platform-card">
              <div className="hp-platform-icon">
                <svg width="32" height="32" fill="none" viewBox="0 0 24 24" stroke="#2563eb" strokeWidth={1.8}>
                  <circle cx="12" cy="12" r="10" />
                  <line x1="2" y1="12" x2="22" y2="12" />
                  <path d="M12 2a15.3 15.3 0 0 1 4 10 15.3 15.3 0 0 1-4 10 15.3 15.3 0 0 1-4-10 15.3 15.3 0 0 1 4-10z" />
                </svg>
              </div>
              <h3 className="hp-platform-name">Web Browser</h3>
              <p className="hp-platform-desc">Akses langsung dari semua browser tanpa perlu instalasi aplikasi tambahan.</p>
              <span className="hp-platform-badge hp-badge-outline-blue">Instant Access</span>
            </div>
            <a
              href="https://github.com/zuckclaw/Formax/releases/download/v1.0.0/app-release.apk"
              target="_blank"
              rel="noopener noreferrer"
              className="hp-platform-card hp-platform-card-link"
              title="Buka rilis APK Android Formax di GitHub"
            >
              <div className="hp-platform-icon">
                <svg width="32" height="32" fill="none" viewBox="0 0 24 24" stroke="#2563eb" strokeWidth={1.8}>
                  <rect x="5" y="2" width="14" height="20" rx="2" />
                  <line x1="12" y1="18" x2="12.01" y2="18" />
                </svg>
              </div>
              <h3 className="hp-platform-name">Android & Mobile</h3>
              <p className="hp-platform-desc">Pengalaman pengisian form yang cepat, nyaman, dan responsif pada smartphone. Klik untuk unduh APK.</p>
              <span className="hp-platform-badge hp-badge-outline-blue" style={{ display: 'inline-flex', alignItems: 'center', gap: '6px' }}>
                Unduh APK Android
                <svg width="14" height="14" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                  <path strokeLinecap="round" strokeLinejoin="round" d="M13.5 6H5.25A2.25 2.25 0 003 8.25v10.5A2.25 2.25 0 005.25 21h10.5A2.25 2.25 0 0018 18.75V10.5m-10.5 6L21 3m0 0h-5.25M21 3v5.25" />
                </svg>
              </span>
            </a>
          </div>
        </div>
      </section>

      {/* ── CTA ── */}
      <section id="cara-pakai" className="hp-cta">
        <div className="hp-cta-inner">
          <h2 className="hp-cta-title">Siap Memulai Form Pertama Anda?</h2>
          <p className="hp-cta-sub">
            Bergabunglah sekarang dan rasakan kemudahan membuat form & ujian interaktif secara gratis.
          </p>
          <Link to="/auth" id="btn-cta-daftar" className="hp-btn-cta" onClick={handleCtaClick}>
            Daftar Sekarang - Gratis
          </Link>
        </div>
      </section>

      {/* ── FOOTER ── */}
      <footer className="hp-footer">
        <div className="hp-footer-inner">
          <div className="hp-footer-top">
            <div className="hp-footer-brand-wrap">
              <span className="hp-footer-brand">Form4x</span>
              <p className="hp-footer-tagline">Tempat membuat Form Terlengkap & Terpercaya.</p>
            </div>
            <div className="hp-footer-links">
              <Link to="/">Beranda</Link>
              <Link to="/tentang">Tentang</Link>
              <Link to="/cara-pakai">Cara Pakai</Link>
              <Link to="/auth">Login</Link>
            </div>
          </div>
          <div className="hp-footer-divider" />
          <p className="hp-footer-copy">© 2026 Form4x. All rights reserved.</p>
        </div>
      </footer>
    </div>
  );
};

export default HomePage;