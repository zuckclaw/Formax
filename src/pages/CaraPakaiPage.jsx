import { Link } from 'react-router-dom'
import { useState, useEffect, useRef } from 'react'

/* ─── Shared Navbar Component ─── */
function LandingNav({ active = 'cara-pakai' }) {
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

const CaraPakaiPage = () => {
  const containerRef = useRef(null)
  const stepRefs = [useRef(null), useRef(null), useRef(null)]
  const [lineProgress, setLineProgress] = useState(0) // Smooth interpolated progress
  const [activeSteps, setActiveSteps] = useState([false, false, false])

  const targetProgressRef = useRef(0)
  const currentProgressRef = useRef(0)
  const animationFrameRef = useRef(null)

  useEffect(() => {
    const handleScroll = () => {
      if (!containerRef.current) return

      const container = containerRef.current
      const rect = container.getBoundingClientRect()
      
      const triggerY = window.innerHeight * 0.45
      const scrolled = triggerY - rect.top
      const totalHeight = rect.height
      const padding = 100
      
      let progress = scrolled / (totalHeight - padding)
      if (progress < 0) progress = 0
      if (progress > 1) progress = 1
      
      setLineProgress(progress * 100)

      // Calculate fill position in screen coordinates
      const yFillScreen = rect.top + 24 + (progress * rect.height)

      const updatedActive = stepRefs.map((ref) => {
        if (!ref.current) return false
        const stepRect = ref.current.getBoundingClientRect()
        // Center of the step circle node in screen Y pixels
        const nodeCenterScreenY = stepRect.top + 16
        return yFillScreen >= nodeCenterScreenY
      })
      
      setActiveSteps(updatedActive)
    }

    window.addEventListener('scroll', handleScroll, { passive: true })
    window.addEventListener('resize', handleScroll)
    
    // Initial calculation
    handleScroll()
    
    // Safety check after a short delay to ensure layout is complete
    const timeoutId = setTimeout(handleScroll, 100)
    
    return () => {
      window.removeEventListener('scroll', handleScroll)
      window.removeEventListener('resize', handleScroll)
      clearTimeout(timeoutId)
    }
  }, [])

  return (
    <div className="hp-root">
      {/* ── NAVBAR ── */}
      <LandingNav active="cara-pakai" />

      {/* ── HERO ── */}
      <section className="cp-hero">
        <div className="cp-hero-inner">
          <h1 className="cp-hero-title">
            Cara Menggunakan <span className="cp-hero-accent">formMaker</span>
          </h1>
          <p className="cp-hero-sub">
            Panduan singkat untuk mulai membuat, membagikan, dan memantau form
            Anda — semua langsung dari browser.
          </p>
          <Link to="/register" className="cp-btn-primary">
            Mulai Sekarang
          </Link>
        </div>
      </section>

      {/* ── TIMELINE GUIDES SECTION ── */}
      <section className="cp-timeline-section">
        <div className="cp-timeline-container" ref={containerRef}>
          {/* Background Line */}
          <div className="cp-timeline-line" />
          
          {/* Animated Scroll Fill Line */}
          <div 
            className="cp-timeline-line-fill" 
            style={{ height: `${lineProgress}%` }} 
          >
            {lineProgress > 0 && (
              <div className="cp-timeline-line-tip">
                <div className="cp-tip-halo" />
                <div className="cp-tip-dot" />
              </div>
            )}
          </div>


          {/* ── LANGKAH 1 ── */}
          <div 
            className={`cp-step-block${activeSteps[0] ? ' cp-step-active' : ''}`}
            ref={stepRefs[0]}
          >
            <div className="cp-step-node">
              <div className="cp-node-circle">
                <div className="cp-node-dot" />
              </div>
            </div>

            <div className="cp-step-content">
              <div className="cp-step-badge">LANGKAH 1</div>
              <h2 className="cp-step-title">
                <span className="cp-step-icon">👤+</span> Daftar Akun
              </h2>
              <p className="cp-step-desc">
                Cukup daftar dengan email, tanpa perlu mengunduh apa pun untuk mulai menggunakan formMaker di browser.
              </p>


              <div className="cp-card-grid">
                <div className="cp-subcard">
                  <div className="cp-num-badge">1</div>
                  <div className="cp-card-text">
                    <h4>Buka Halaman Daftar</h4>
                    <p>Klik tombol "Daftar Gratis" di halaman utama formMaker.</p>
                  </div>
                </div>

                <div className="cp-subcard">
                  <div className="cp-num-badge">2</div>
                  <div className="cp-card-text">
                    <h4>Isi Data Diri</h4>
                    <p>Masukkan nama, email, dan kata sandi Anda.</p>
                  </div>
                </div>

                <div className="cp-subcard">
                  <div className="cp-num-badge">3</div>
                  <div className="cp-card-text">
                    <h4>Verifikasi Email</h4>
                    <p>Cek kotak masuk Anda dan klik tautan verifikasi yang dikirim.</p>
                  </div>
                </div>

                <div className="cp-subcard cp-card-success">
                  <div className="cp-check-badge">✓</div>
                  <div className="cp-card-text">
                    <h4>Selesai!</h4>
                    <p>Akun Anda siap dipakai — langsung masuk ke dashboard.</p>
                  </div>
                </div>
              </div>
            </div>
          </div>

          {/* ── LANGKAH 2 ── */}
          <div 
            className={`cp-step-block${activeSteps[1] ? ' cp-step-active' : ''}`}
            ref={stepRefs[1]}
          >
            <div className="cp-step-node">
              <div className="cp-node-circle">
                <div className="cp-node-dot" />
              </div>
            </div>

            <div className="cp-step-content">
              <div className="cp-step-badge">LANGKAH 2</div>
              <h2 className="cp-step-title">
                <span className="cp-step-icon">📄</span> Buat Form
              </h2>
              <p className="cp-step-desc">
                Susun form baru dari template siap pakai atau mulai dari halaman kosong.
              </p>

              <div className="cp-card-grid">
                <div className="cp-subcard">
                  <div className="cp-num-badge">1</div>
                  <div className="cp-card-text">
                    <h4>Klik "+"</h4>
                    <p>Dari dashboard, klik tombol untuk membuat form baru.</p>
                  </div>
                </div>

                <div className="cp-subcard">
                  <div className="cp-num-badge">2</div>
                  <div className="cp-card-text">
                    <h4>Pilih Template / Kosong</h4>
                    <p>Gunakan template siap pakai, atau susun pertanyaan dari nol.</p>
                  </div>
                </div>

                <div className="cp-subcard">
                  <div className="cp-num-badge">3</div>
                  <div className="cp-card-text">
                    <h4>Atur Tema & Timer</h4>
                    <p>Pilih tema tampilan, dan aktifkan timer auto-submit bila perlu.</p>
                  </div>
                </div>

                <div className="cp-subcard cp-card-success">
                  <div className="cp-check-badge">✓</div>
                  <div className="cp-card-text">
                    <h4>Publikasikan</h4>
                    <p>Klik "Terbitkan" agar form siap dibagikan ke responden.</p>
                  </div>
                </div>
              </div>
            </div>
          </div>

          {/* ── LANGKAH 3 ── */}
          <div 
            className={`cp-step-block${activeSteps[2] ? ' cp-step-active' : ''}`}
            ref={stepRefs[2]}
          >
            <div className="cp-step-node">
              <div className="cp-node-circle">
                <div className="cp-node-dot" />
              </div>
            </div>

            <div className="cp-step-content">
              <div className="cp-step-badge">LANGKAH 3</div>
              <h2 className="cp-step-title">
                <span className="cp-step-icon">🔗</span> Bagikan & Pantau
              </h2>
              <p className="cp-step-desc">
                Sebarkan form Anda dan pantau jawaban yang masuk secara real-time.
              </p>

              <div className="cp-card-grid">
                <div className="cp-subcard">
                  <div className="cp-num-badge">1</div>
                  <div className="cp-card-text">
                    <h4>Salin Tautan / QR</h4>
                    <p>Setiap form otomatis punya tautan dan kode QR sendiri.</p>
                  </div>
                </div>

                <div className="cp-subcard">
                  <div className="cp-num-badge">2</div>
                  <div className="cp-card-text">
                    <h4>Sebarkan ke Responden</h4>
                    <p>Bagikan lewat WhatsApp, email, atau media sosial.</p>
                  </div>
                </div>

                <div className="cp-subcard">
                  <div className="cp-num-badge">3</div>
                  <div className="cp-card-text">
                    <h4>Pantau Respon Masuk</h4>
                    <p>Lihat jawaban yang masuk secara real-time langsung dari dashboard.</p>
                  </div>
                </div>

                <div className="cp-subcard cp-card-success">
                  <div className="cp-check-badge">✓</div>
                  <div className="cp-card-text">
                    <h4>Selesai!</h4>
                    <p>Ekspor hasil respons ke spreadsheet kapan saja Anda butuhkan.</p>
                  </div>
                </div>
              </div>

              {/* Optional Settings Card */}
              <div className="cp-subcard cp-card-optional">
                <div className="cp-opt-badge">OPT</div>
                <div className="cp-card-text">
                  <h4>Pengaturan Opsional</h4>
                  <p>
                    Anda bisa mengubah tema, menambah pertanyaan baru, atau mengatur ulang timer kapan saja lewat menu Pengaturan Form.
                  </p>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* ── FEATURES GRID SECTION ── */}
      <section className="cp-features-section">
        <div className="cp-features-inner">
          <div className="cp-features-header">
            <span className="cp-features-icon-spark">✨</span>
            <h2 className="cp-features-title">Fitur yang Tersedia</h2>
          </div>
          <p className="cp-features-sub">
            formMaker hadir dengan berbagai fitur untuk membuat form Anda lebih rapi dan mudah dikelola.
          </p>

          <div className="cp-features-grid">
            <div className="cp-feature-card">
              <div className="cp-feature-icon-box">⚡</div>
              <h3>Buat Form Cepat</h3>
              <p>Susun form baru hanya dalam hitungan menit, tanpa proses yang rumit.</p>
            </div>

            <div className="cp-feature-card">
              <div className="cp-feature-icon-box">🎨</div>
              <h3>Tema Menarik</h3>
              <p>Pilih tampilan yang rapi dan modern untuk setiap form yang Anda buat.</p>
            </div>

            <div className="cp-feature-card">
              <div className="cp-feature-icon-box">⏱️</div>
              <h3>Timer Otomatis</h3>
              <p>Atur batas waktu pengisian dengan auto-submit begitu waktu habis.</p>
            </div>

            <div className="cp-feature-card">
              <div className="cp-feature-icon-box">🔲</div>
              <h3>Kode QR</h3>
              <p>Setiap form otomatis mendapat kode QR sendiri, siap untuk dibagikan.</p>
            </div>

            <div className="cp-feature-card">
              <div className="cp-feature-icon-box">📊</div>
              <h3>Export ke Spreadsheet</h3>
              <p>Semua jawaban rapi terekspor ke spreadsheet, siap diolah kapan saja.</p>
            </div>

            <div className="cp-feature-card">
              <div className="cp-feature-icon-box">🔒</div>
              <h3>Akses Aman</h3>
              <p>Masuk dengan akun pribadi Anda — data form dan respons tetap terjaga.</p>
            </div>
          </div>
        </div>
      </section>

      {/* ── FOOTER ── */}
      <footer className="hp-footer">
        <div className="hp-footer-inner">
          <div className="hp-footer-brand">formMaker</div>
          <p className="hp-footer-copy">© 2024 formMaker. All rights reserved.</p>
        </div>
      </footer>
    </div>
  )
}

export default CaraPakaiPage
