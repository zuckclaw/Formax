import { Link } from 'react-router-dom'

/* ─── App Dashboard Mockup (dari screenshot ke-2 user) ─── */
function AppMockup() {
  return (
    <div className="hp-mockup-wrap">
      <div className="hp-mockup">
        {/* Header (Spans full width on top) */}
        <header className="hp-mock-header">
          <div className="hp-mock-logo-section">
            <div className="hp-mock-logo-box">
              <span className="hp-mock-logo-text-f4">F4</span>
            </div>
            <div className="hp-mock-logo-desc">
              <div className="hp-mock-app-name">Form4x</div>
              <div className="hp-mock-app-tagline">Tempat membuat Form Terlengkap</div>
            </div>
          </div>
          <div className="hp-mock-search-wrapper">
            <div className="hp-mock-search-bar">
              <span className="hp-mock-search-icon">🔍</span>
              <span className="hp-mock-search-placeholder">Search</span>
            </div>
          </div>
        </header>

        {/* Bottom Section: Sidebar + Main Content */}
        <div className="hp-mock-body">
          {/* Sidebar */}
          <aside className="hp-mock-sidebar">
            <nav className="hp-mock-nav">
              <div className="hp-mock-nav-item hp-mock-nav-active">
                <span className="hp-mock-nav-icon">
                  <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
                    <rect x="3" y="3" width="7" height="7" rx="1" /><rect x="14" y="3" width="7" height="7" rx="1" />
                    <rect x="3" y="14" width="7" height="7" rx="1" /><rect x="14" y="14" width="7" height="7" rx="1" />
                  </svg>
                </span>
                Dashboard
              </div>
              <div className="hp-mock-nav-item">
                <span className="hp-mock-nav-icon">
                  <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
                    <rect x="3" y="3" width="18" height="18" rx="2" /><path d="M3 9h18M9 21V9" />
                  </svg>
                </span>
                Template
              </div>
              <div className="hp-mock-nav-item">
                <span className="hp-mock-nav-icon">
                  <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
                    <polyline points="12 8 12 12 14 14" /><circle cx="12" cy="12" r="9" />
                  </svg>
                </span>
                History
              </div>
            </nav>

            <div className="hp-mock-sidebar-footer">
              <div className="hp-mock-avatar-wrap">
                <div className="hp-mock-avatar-color" />
              </div>
              <span className="hp-mock-user-name">Gita NUr</span>
              <span className="hp-mock-logout-btn">
                <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
                  <path d="M9 21H5a2 2 0 01-2-2V5a2 2 0 012-2h4M16 17l5-5-5-5M21 12H9" />
                </svg>
              </span>
            </div>
          </aside>

          {/* Main Area */}
          <main className="hp-mock-main">
            {/* Template row */}
            <div className="hp-mock-template-row">
              {/* Create New */}
              <div className="hp-mock-card hp-mock-card-create">
                <div className="hp-mock-create-circle">
                  <span className="hp-mock-create-plus">+</span>
                </div>
                <div className="hp-mock-card-label">Create New Template</div>
              </div>

              {/* Blank Form */}
              <div className="hp-mock-card">
                <div className="hp-mock-card-preview hp-mock-preview-blank">
                  <div className="hp-mock-line hp-mock-line-full" />
                  <div className="hp-mock-line hp-mock-line-full" />
                  <div className="hp-mock-rect-blue" />
                </div>
                <div className="hp-mock-card-footer">
                  <div className="hp-mock-card-title">Blank Form</div>
                  <div className="hp-mock-card-sub">Start from scratch</div>
                </div>
              </div>

              {/* Attendance Form */}
              <div className="hp-mock-card">
                <div className="hp-mock-card-preview hp-mock-preview-attend">
                  <div className="hp-mock-attend-dot" />
                  <div className="hp-mock-attend-dot" style={{ opacity: 0.5 }} />
                  <div className="hp-mock-line hp-mock-line-full" style={{ marginTop: 8 }} />
                </div>
                <div className="hp-mock-card-footer">
                  <div className="hp-mock-card-title">Attendance Form</div>
                  <div className="hp-mock-card-sub">Event or class tracking</div>
                </div>
              </div>

              {/* Exam Form */}
              <div className="hp-mock-card hp-mock-card-exam">
                <span className="hp-mock-card-badge">⏱ Timer enabled by default</span>
                <div className="hp-mock-card-preview hp-mock-preview-exam">
                  <div className="hp-mock-line-orange" />
                  <div className="hp-mock-line hp-mock-line-full" />
                  <div className="hp-mock-line hp-mock-line-half" />
                </div>
                <div className="hp-mock-card-footer">
                  <div className="hp-mock-card-title">Exam Form</div>
                  <div className="hp-mock-card-sub">Assessments & Quizzes</div>
                </div>
              </div>
            </div>

            {/* Recent History Header */}
            <div className="hp-mock-section-title">Recent History</div>

            {/* History Cards */}
            <div className="hp-mock-history-row">
              {[
                { title: 'Quizz', sub: 'Updated 2 days ago', lines: 2 },
                { title: 'Ujian', sub: 'Updated 1 week ago', lines: 1 },
                { title: 'Angket Classmeet', sub: 'Updated 1 month ago', lines: 3 },
              ].map((item, i) => (
                <div key={i} className="hp-mock-history-card">
                  <div className="hp-mock-history-thumb">
                    {Array.from({ length: item.lines }).map((_, li) => (
                      <div key={li} className="hp-mock-hist-line" style={{ width: li === 1 ? '70%' : li === 2 ? '50%' : '85%' }} />
                    ))}
                  </div>
                  <div className="hp-mock-history-footer">
                    <div>
                      <div className="hp-mock-hist-title">{item.title}</div>
                      <div className="hp-mock-hist-sub">{item.sub}</div>
                    </div>
                    <span className="hp-mock-dots">•••</span>
                  </div>
                </div>
              ))}
            </div>
          </main>
        </div>
      </div>
    </div>
  )
}

/* ─── Feature Card ─── */
function FeatureCard({ icon, title, desc, highlight = false }) {
  return (
    <div className={`hp-feat-card${highlight ? ' hp-feat-highlight' : ''}`}>
      <div className="hp-feat-icon">{icon}</div>
      <div className="hp-feat-title">{title}</div>
      <div className="hp-feat-desc">{desc}</div>
    </div>
  )
}

/* ─── Main HomePage ─── */
const HomePage = () => {
  const features = [
    {
      icon: (
        <svg width="22" height="22" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.8}>
          <circle cx="12" cy="12" r="10" /><path d="M8 14s1.5 2 4 2 4-2 4-2" /><line x1="9" y1="9" x2="9.01" y2="9" /><line x1="15" y1="9" x2="15.01" y2="9" />
        </svg>
      ),
      title: 'Tema Menarik',
      desc: 'Sesuaikan tampilan form Anda dengan berbagai pilihan tema profesional.',
    },
    {
      icon: (
        <svg width="22" height="22" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.8}>
          <rect x="2" y="3" width="20" height="14" rx="2" /><path d="M8 21h8M12 17v4" />
        </svg>
      ),
      title: 'Multi-Platform',
      desc: 'Akses dan berdua form dari browser web atau Android dengan mudah.',
    },
    {
      icon: (
        <svg width="22" height="22" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.8}>
          <path d="M21.5 2v6h-6M2.5 22v-6h6M2 11.5a10 10 0 0 1 18.8-4.3M22 12.5a10 10 0 0 1-18.8 4.2" />
        </svg>
      ),
      title: 'Sinkronisasi Otomatis',
      desc: 'Data respons langsung tersinkronisasi ke spreadsheet favorit Anda secara real-time.',
    },
    {
      icon: (
        <svg width="22" height="22" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.8}>
          <path d="M13 2L3 14h9l-1 8 10-12h-9l1-8z" />
        </svg>
      ),
      title: 'Cepat & Andal',
      desc: 'Infrastruktur yang dibangun untuk kecepatan dan keandalan maksimal tanpa waktu henti.',
    },
    {
      icon: (
        <svg width="22" height="22" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.8}>
          <circle cx="12" cy="12" r="10" /><polyline points="12 6 12 12 16 14" />
        </svg>
      ),
      title: 'Timer Real-time',
      desc: 'Batasi waktu pengerjaan form dengan timer akurat, cocok untuk ujian atau kuis online.',
    },
    {
      icon: (
        <svg width="22" height="22" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.8}>
          <circle cx="12" cy="12" r="10" /><line x1="2" y1="12" x2="22" y2="12" /><path d="M12 2a15.3 15.3 0 0 1 4 10 15.3 15.3 0 0 1-4 10 15.3 15.3 0 0 1-4-10 15.3 15.3 0 0 1 4-10z" />
        </svg>
      ),
      title: 'Gratis & Terbuka',
      desc: 'Nikmati fitur dasar secara gratis dan kembangkan form tanpa batasan rutin.',
    },
  ]

  return (
    <div className="hp-root">
      {/* ── NAVBAR ── */}
      <header className="hp-header">
        <div className="hp-header-inner">
          <div className="hp-brand">
            <span className="hp-brand-text">formMaker</span>
          </div>
          <nav className="hp-nav">
            <Link to="/" className="hp-nav-link hp-nav-active">Beranda</Link>
            <Link to="/tentang" className="hp-nav-link">Tentang</Link>
            <Link to="/cara-pakai" className="hp-nav-link">Cara Pakai</Link>
          </nav>
          <div className="hp-header-actions">
            <Link to="/login" className="hp-btn-login">Login</Link>
            <Link to="/register" className="hp-btn-register">Register</Link>
          </div>
        </div>
      </header>


      {/* ── HERO ── */}
      <section id="beranda" className="hp-hero">
        <div className="hp-hero-inner">
          <h1 className="hp-hero-title">
            Buat Form Anda <span className="hp-hero-accent">dengan Mudah</span>
          </h1>
          <p className="hp-hero-sub">
            Tingkatkan produktivitas dengan platform pembuatan form/r profesional.
            Dilengkapi dengan timer terintegrasi, pembuatan kode QR instan, dan
            sinkronisasi otomatis ke spreadsheet.
          </p>
          <div className="hp-hero-actions">
            <Link to="/register" id="btn-daftar-gratis" className="hp-btn-primary">
              Daftar Gratis
            </Link>
            <a href="#fitur" className="hp-btn-outline">
              Pelajari Lebih Lanjut
            </a>
          </div>

          {/* App Preview */}
          <div className="hp-mockup-wrap">
            <img 
              src="/images/Dashboard.png" 
              alt="formMaker Dashboard Preview" 
              style={{ width: '100%', height: 'auto', display: 'block' }}
            />
          </div>
        </div>
      </section>

      {/* ── FEATURES ── */}
      <section id="fitur" className="hp-features">
        <div className="hp-section-inner">
          <h2 className="hp-section-title">Fitur Canggih</h2>
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
          <h2 className="hp-section-title">Tersedia Di Mana Saja</h2>
          <div className="hp-platform-row">
            <div className="hp-platform-card">
              <div className="hp-platform-icon">
                <svg width="32" height="32" fill="none" viewBox="0 0 24 24" stroke="#2563eb" strokeWidth={1.5}>
                  <circle cx="12" cy="12" r="10" /><line x1="2" y1="12" x2="22" y2="12" />
                  <path d="M12 2a15.3 15.3 0 0 1 4 10 15.3 15.3 0 0 1-4 10 15.3 15.3 0 0 1-4-10 15.3 15.3 0 0 1 4-10z" />
                </svg>
              </div>
              <div className="hp-platform-name">Web Browser</div>
              <span className="hp-platform-badge hp-badge-outline-blue">Instant</span>
            </div>
            <div className="hp-platform-card">
              <div className="hp-platform-icon">
                <svg width="32" height="32" fill="none" viewBox="0 0 24 24" stroke="#2563eb" strokeWidth={1.5}>
                  <rect x="5" y="2" width="14" height="20" rx="2" /><line x1="12" y1="18" x2="12.01" y2="18" />
                </svg>
              </div>
              <div className="hp-platform-name">Android</div>
              <span className="hp-platform-badge hp-badge-outline-blue">Download</span>
            </div>
          </div>
        </div>
      </section>

      {/* ── CTA ── */}
      <section id="cara-pakai" className="hp-cta">
        <div className="hp-cta-inner">
          <h2 className="hp-cta-title">Siap Memulai?</h2>
          <Link to="/register" id="btn-cta-daftar" className="hp-btn-cta">
            Daftar Sekarang - Gratis
          </Link>
        </div>
      </section>

      {/* ── FOOTER ── */}
      <footer className="hp-footer">
        <div className="hp-footer-inner">
          <div className="hp-footer-brand">formMaker</div>
          <p className="hp-footer-copy">© 2026 formMaker. All rights reserved.</p>
        </div>
      </footer>
    </div>
  )
}

export default HomePage
