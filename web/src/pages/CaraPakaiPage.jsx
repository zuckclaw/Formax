import { Link } from 'react-router-dom'
import { useState, useEffect, useRef } from 'react'
import '../styles/landing.css'

import InteractiveCubeBackground from '../components/InteractiveCubeBackground';
import LandingNav from '../components/LandingNav';
import LandingFooter from '../components/LandingFooter';

const CaraPakaiPage = () => {
  const containerRef = useRef(null)
  const stepRefs = useRef([])
  const [lineProgress, setLineProgress] = useState(0)
  const [activeSteps, setActiveSteps] = useState([false, false, false])

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

      const updatedActive = stepRefs.current.map((el) => {
        if (!el) return false
        const stepRect = el.getBoundingClientRect()
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
    <div className="hp-root" style={{ position: 'relative' }}>
      <InteractiveCubeBackground />
      {/* ── NAVBAR ── */}
      <LandingNav active="cara-pakai" />

      {/* ── HERO ── */}
      <section className="cp-hero">
        <div className="cp-hero-inner">
          <h1 className="cp-hero-title">
            Cara Menggunakan <span className="cp-hero-accent">Form4x</span>
          </h1>
          <p className="cp-hero-sub">
            Panduan singkat untuk mulai membuat, membagikan,
            <br /> dan memantau form Anda — semua langsung dari browser.
          </p>
          <Link to="/auth" className="cp-btn-primary">
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
            ref={(el) => { stepRefs.current[0] = el }}
          >
            <div className="cp-step-node">
              <div className="cp-node-circle">
                <div className="cp-node-dot" />
              </div>
            </div>

            <div className="cp-step-content">
              <div className="cp-step-badge">LANGKAH 1</div>
              <h2 className="cp-step-title">
                <span className="cp-step-icon">
                  <svg fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2} strokeLinecap="round" strokeLinejoin="round">
                    <path d="M16 21v-2a4 4 0 00-4-4H6a4 4 0 00-4 4v2" />
                    <circle cx="9" cy="7" r="4" />
                    <line x1="19" y1="8" x2="19" y2="14" />
                    <line x1="22" y1="11" x2="16" y2="11" />
                  </svg>
                </span> Daftar Akun
              </h2>
              <p className="cp-step-desc">
                Cukup daftar dengan email, tanpa perlu mengunduh apa pun untuk mulai menggunakan Form4x di browser.
              </p>


              <div className="cp-card-grid">
                <div className="cp-subcard">
                  <div className="cp-num-badge">1</div>
                  <div className="cp-card-text">
                    <h4>Buka Halaman Daftar</h4>
                    <p>Klik tombol "Daftar Gratis" di halaman utama Form4x.</p>
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
            ref={(el) => { stepRefs.current[1] = el }}
          >
            <div className="cp-step-node">
              <div className="cp-node-circle">
                <div className="cp-node-dot" />
              </div>
            </div>

            <div className="cp-step-content">
              <div className="cp-step-badge">LANGKAH 2</div>
              <h2 className="cp-step-title">
                <span className="cp-step-icon">
                  <svg fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2} strokeLinecap="round" strokeLinejoin="round">
                    <path d="M14 2H6a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V8z" />
                    <polyline points="14 2 14 8 20 8" />
                    <line x1="16" y1="13" x2="8" y2="13" />
                    <line x1="16" y1="17" x2="8" y2="17" />
                  </svg>
                </span> Buat Form
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
                    <h4>Gunakan AI / Import Word / Timer</h4>
                    <p>Manfaatkan Formax AI Builder, impor Word (.docx), atau aktifkan timer auto-submit.</p>
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
            ref={(el) => { stepRefs.current[2] = el }}
          >
            <div className="cp-step-node">
              <div className="cp-node-circle">
                <div className="cp-node-dot" />
              </div>
            </div>

            <div className="cp-step-content">
              <div className="cp-step-badge">LANGKAH 3</div>
              <h2 className="cp-step-title">
                <span className="cp-step-icon">
                  <svg fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2} strokeLinecap="round" strokeLinejoin="round">
                    <path d="M10 13a5 5 0 007.54.54l3-3a5 5 0 00-7.07-7.07l-1.72 1.71" />
                    <path d="M14 11a5 5 0 00-7.54-.54l-3 3a5 5 0 007.07 7.07l1.71-1.71" />
                  </svg>
                </span> Bagikan &amp; Pantau
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
                    Anda dapat menggunakan Formax AI Builder, mengimpor file Word, atau mengaktifkan timer &amp; pengacak soal kapan saja lewat Editor Formax.
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
            <span className="cp-features-icon-spark">
              <svg fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2} strokeLinecap="round" strokeLinejoin="round">
                <path d="M9.813 15.904L9 18.75l-.813-2.846a4.5 4.5 0 00-3.09-3.09L2.25 12l2.846-.813a4.5 4.5 0 003.09-3.09L9 5.25l.813 2.846a4.5 4.5 0 003.09 3.09L15.75 12l-2.846.813a4.5 4.5 0 00-3.09 3.09zM18.259 8.715L18 9.75l-.259-1.035a3.375 3.375 0 00-2.455-2.456L14.25 6l1.036-.259a3.375 3.375 0 002.455-2.456L18 2.25l.259 1.035a3.375 3.375 0 002.456 2.456L21.75 6l-1.035.259a3.375 3.375 0 00-2.456 2.456z" />
              </svg>
            </span>
            <h2 className="cp-features-title">Fitur yang Tersedia</h2>
          </div>
          <p className="cp-features-sub">
            Form4x hadir dengan berbagai fitur canggih untuk membuat form Anda lebih rapi, cepat, dan mudah dikelola.
          </p>

          <div className="cp-features-grid">
            <div className="cp-feature-card">
              <div className="cp-feature-icon-box">
                <svg fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2} strokeLinecap="round" strokeLinejoin="round">
                  <path d="M9.813 15.904L9 18.75l-.813-2.846a4.5 4.5 0 00-3.09-3.09L2.25 12l2.846-.813a4.5 4.5 0 003.09-3.09L9 5.25l.813 2.846a4.5 4.5 0 003.09 3.09L15.75 12l-2.846.813a4.5 4.5 0 00-3.09 3.09zM18.259 8.715L18 9.75l-.259-1.035a3.375 3.375 0 00-2.455-2.456L14.25 6l1.036-.259a3.375 3.375 0 002.455-2.456L18 2.25l.259 1.035a3.375 3.375 0 002.456 2.456L21.75 6l-1.035.259a3.375 3.375 0 00-2.456 2.456z" />
                </svg>
              </div>
              <h3>AI Form Builder</h3>
              <p>Buat form, kuis, dan ujian cerdas secara otomatis dalam hitungan detik menggunakan AI.</p>
            </div>

            <div className="cp-feature-card">
              <div className="cp-feature-icon-box">
                <svg fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2} strokeLinecap="round" strokeLinejoin="round">
                  <polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2" />
                </svg>
              </div>
              <h3>Buat Form Cepat</h3>
              <p>Susun form baru dengan editor serbaguna dan berbagai jenis pilihan pertanyaan.</p>
            </div>

            <div className="cp-feature-card">
              <div className="cp-feature-icon-box">
                <svg fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2} strokeLinecap="round" strokeLinejoin="round">
                  <circle cx="12" cy="12" r="10" />
                  <polyline points="12 6 12 12 16 14" />
                </svg>
              </div>
              <h3>Timer Otomatis</h3>
              <p>Atur batas waktu pengisian dengan auto-submit begitu waktu habis.</p>
            </div>

            <div className="cp-feature-card">
              <div className="cp-feature-icon-box">
                <svg fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2} strokeLinecap="round" strokeLinejoin="round">
                  <path d="M12 4v1m6 11h2m-6 0h-2v4m0-4v-3m0 0h3m-3 0h-3m-2-5h4m-4 0v4m0-4V7m14 4v4m0 0h-3m3 0v3m-3-3h-3m3-3V7m-7 4h.01M7 4h10" />
                </svg>
              </div>
              <h3>Kode QR &amp; Link</h3>
              <p>Setiap form otomatis mendapat kode QR &amp; tautan unik, siap untuk dibagikan.</p>
            </div>

            <div className="cp-feature-card">
              <div className="cp-feature-icon-box">
                <svg fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2} strokeLinecap="round" strokeLinejoin="round">
                  <path d="M9 17v-2m3 2v-4m3 4v-6m2 10H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                </svg>
              </div>
              <h3>Export ke Spreadsheet</h3>
              <p>Semua jawaban rapi terekspor ke file Excel/Spreadsheet, siap diolah kapan saja.</p>
            </div>

            <div className="cp-feature-card">
              <div className="cp-feature-icon-box">
                <svg fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2} strokeLinecap="round" strokeLinejoin="round">
                  <rect x="3" y="11" width="18" height="11" rx="2" ry="2" />
                  <path d="M7 11V7a5 5 0 0110 0v4" />
                </svg>
              </div>
              <h3>Akses Aman &amp; Ujian</h3>
              <p>Mode fullscreen wajib, pengacak opsi jawaban, dan perlindungan data yang terjaga.</p>
            </div>
          </div>
        </div>
      </section>

      {/* ── FOOTER ── */}
      <LandingFooter />
    </div>
  )
}

export default CaraPakaiPage
