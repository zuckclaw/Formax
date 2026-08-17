import { Link } from 'react-router-dom'

/* ─── Shared Navbar ─── */
function LandingNav({ active = 'beranda' }) {
  return (
    <header className="hp-header">
      <div className="hp-header-inner">
        <div className="hp-brand">
          <Link to="/" className="hp-brand-text" style={{ textDecoration: 'none' }}>
            formMaker
          </Link>
        </div>
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
          <Link to="/login" className="hp-btn-login">Login</Link>
          <Link to="/register" className="hp-btn-register">Register</Link>
        </div>
      </div>
    </header>
  )
}

/* ─── Step Card ─── */
function StepCard({ number, color, title, desc }) {
  return (
    <div className="tp-step">
      <div className="tp-step-box" style={{ background: color }}>
        <span className="tp-step-num">{number}</span>
      </div>
      <h3 className="tp-step-title">{title}</h3>
      <p className="tp-step-desc">{desc}</p>
    </div>
  )
}

/* ─── TentangPage ─── */
const TentangPage = () => {
  const steps = [
    {
      number: '01',
      color: '#1e3a8a',
      title: 'Daftar Akun',
      desc: 'Buat akun gratis hanya dengan email, langsung dari browser.',
    },
    {
      number: '02',
      color: '#4361ee',
      title: 'Buat Form',
      desc: 'Susun form sendiri atau pakai template, atur tema dan timer bila perlu.',
    },
    {
      number: '03',
      color: '#10b981',
      title: 'Bagikan & Pantau',
      desc: 'Sebar lewat tautan atau kode QR, lalu pantau jawaban secara real-time.',
    },
  ]

  return (
    <div className="hp-root">
      {/* ── NAVBAR ── */}
      <LandingNav active="tentang" />

      {/* ── HERO TENTANG ── */}
      <section className="tp-hero">
        <div className="tp-hero-inner">
          <h1 className="tp-hero-title">
            Merancang Formulir Kini Semakin<br />
            Mudah, Cepat, dan Efisien
          </h1>
          <p className="tp-hero-sub">
            formMaker dirancang untuk menyederhanakan proses pembuatan formulir
            kompleks. Dengan antarmuka yang bersih dan alat logika yang kuat,
            kumpulkan data yang Anda butuhkan tanpa kerumitan teknis.
          </p>
          <Link to="/register" id="btn-tentang-mulai" className="tp-btn-cta">
            Mulai Membuat Form
          </Link>
        </div>
      </section>

      {/* ── CARA KERJA ── */}
      <section className="tp-howto">
        <div className="tp-howto-inner">
          <h2 className="tp-howto-title">Cara Kerja</h2>
          <p className="tp-howto-sub">
            Memulai dengan formMaker itu sederhana. Daftar, buat form, dan bagikan ke
            siapa saja dalam hitungan menit.
          </p>

          {/* Steps */}
          <div className="tp-steps-row">
            {steps.map((step, i) => (
              <div key={i} className="tp-step-wrapper">
                <StepCard {...step} />
                {/* Dashed connector line between boxes */}
                {i < steps.length - 1 && (
                  <div className="tp-step-connector" aria-hidden="true" />
                )}
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* ── FOOTER ── */}
      <footer className="tp-footer">
        <div className="tp-footer-inner">
          <div className="tp-footer-brand">formMaker</div>
          <p className="tp-footer-copy">© 2024 formMaker. All rights reserved.</p>
        </div>
      </footer>
    </div>
  )
}

export default TentangPage
