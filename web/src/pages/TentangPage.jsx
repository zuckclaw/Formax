import { Link } from 'react-router-dom'
import '../styles/landing.css'
import logoForm4x from '../assets/logo_form4x.png';
import ThemeToggle from '../components/ThemeToggle';
import InteractiveCubeBackground from '../components/InteractiveCubeBackground';
import LandingNav from '../components/LandingNav';

/* ─── TentangPage ─── */
const TentangPage = () => {
  const features = [
    { title: 'Formax AI Builder', desc: 'Generate form, kuis, dan ujian cerdas secara otomatis dalam hitungan detik menggunakan AI & formula LaTeX.', icon: 'M9.813 15.904L9 18.75l-.813-2.846a4.5 4.5 0 00-3.09-3.09L2.25 12l2.846-.813a4.5 4.5 0 003.09-3.09L9 5.25l.813 2.846a4.5 4.5 0 003.09 3.09L15.75 12l-2.846.813a4.5 4.5 0 00-3.09 3.09z' },
    { title: 'Pembuatan Form Fleksibel', desc: 'Teks, pilihan ganda, checkbox, dropdown, tanggal, dan upload file dengan editor kaya, validasi, serta pengaturan poin.', icon: 'M9 12h6M12 8v8' },
    { title: 'Import Soal Word', desc: 'Upload file .docx, preview otomatis, dan impor puluhan soal sekaligus tanpa input manual satu per satu.', icon: 'M14 2H6a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V8z M14 2v6h6' },
    { title: 'Penilaian & Timer Otomatis', desc: 'Kunci jawaban presisi, skor real-time, dan timer auto-submit dengan visualisasi rekap jawaban.', icon: 'M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z' },
    { title: 'Keamanan Mode Fullscreen', desc: 'Mode fullscreen wajib, pengacak soal, pengacak opsi jawaban, serta proteksi deteksi pindah tab.', icon: 'M12 15a3 3 0 100-6 3 3 0 000 6z M19 10V9a2 2 0 00-2-2h-1V6a5 5 0 00-10 0v1H5a2 2 0 00-2 2v1' },
    { title: 'QR & Export Spreadsheet', desc: 'Generate Kode QR & link unik per form, serta ekspor seluruh hasil respons ke file Excel/Spreadsheet.', icon: 'M3 3v18h18 M7 16l3-3 3 3 5-5' },
  ]

  const values = [
    { title: 'Cerdas (AI-Powered)', desc: 'Pengemampuan AI untuk membuat kuis, survei, dan soal ujian otomatis dengan cepat.' },
    { title: 'Sederhana', desc: 'Antarmuka bersih dan langkah yang jelas, fokus pada isi bukan pengaturan rumit.' },
    { title: 'Andal & Terstruktur', desc: 'Penyimpanan terstruktur dengan autentikasi aman dan ekspor data yang akurat.' },
    { title: 'Inklusif', desc: 'Dapat diisi dengan atau tanpa akun, mendukung pengisian anonim via identitas browser.' },
  ]

  const team = [
    { name: 'Fathin Jamaluddin', role: 'Project Manager', initials: 'FJ' },
    { name: 'Gita Nur Amalia', role: 'Database Engineer', initials: 'GN' },
    { name: 'Andhika Khairul Fahmi', role: 'UI/UX Designer — Web Dev', initials: 'AK' },
    { name: 'Fajriah Salsabilla', role: 'UI/UX Designer — Web Dev', initials: 'FS' },
    { name: 'Farrel Ghifari', role: 'Android Dev', initials: 'FG' },
    { name: 'Raka Julio Same', role: 'Android Dev', initials: 'RJ' },
  ]

  return (
    <div className="hp-root" style={{ position: 'relative' }}>
      <InteractiveCubeBackground />
      <LandingNav active="tentang" />

      {/* HERO — simetris, clean */}
      <section className="tp-hero tp-hero--about">
        <div className="tp-hero-inner">
          <span className="tp-kicker">Tentang Form4x</span>
          <h1 className="tp-hero-title">Platform Pembuatan Formulir<br />yang Rapi, Cepat, dan Terukur</h1>
          <p className="tp-hero-sub">
            Form4x membantu pendidik, organisasi, dan tim menyusun formulir, kuis, serta survei yang terstruktur dengan alur yang konsisten — dari pembuatan hingga analisis hasil.
          </p>
          <div className="tp-hero-actions">
            <Link to="/auth" className="tp-btn-cta">Mulai Membuat Form</Link>
            <Link to="/cara-pakai" className="tp-btn-ghost">Pelajari Cara Pakai</Link>
          </div>
          <div className="tp-hero-stats">
            <div className="tp-stat"><strong>AI Form</strong><span>Generate Otomatis</span></div>
            <div className="tp-stat-dot" />
            <div className="tp-stat"><strong>Import</strong><span>.docx Sekaligus</span></div>
            <div className="tp-stat-dot" />
            <div className="tp-stat"><strong>Real-time</strong><span>Skor & Rekap</span></div>
          </div>
        </div>
      </section>

      {/* TENTANG SINGKAT — simetris 2 kolom */}
      <section className="tp-about">
        <div className="tp-section-inner">
          <div className="tp-about-grid">
            <div className="tp-about-text">
              <span className="tp-section-kicker">Apa itu Form4x</span>
              <h2 className="tp-section-title">Dirancang untuk Kebutuhan Formulir yang Sesungguhnya</h2>
              <p className="tp-section-desc">
                Form4x berfokus pada kejelasan alur dan keandalan data. Anda dapat menyusun form secara otomatis dengan Formax AI Builder, mengimpor soal dari Word (.docx), atau menyusun dari awal, lalu membagikannya melalui tautan atau Kode QR tanpa langkah tambahan bagi responden.
              </p>
              <p className="tp-section-desc">
                Sistem mendukung penilaian otomatis, kontrol akses berbasis token, batas pengisian, timer auto-submit, serta mode fullscreen untuk integritas ujian. Hasil tersaji dalam rekap yang dapat diekspor ke spreadsheet dan divisualisasikan per pertanyaan.
              </p>
              <ul className="tp-checklist">
                <li>Integrasi Formax AI Builder untuk pembuatan form instan</li>
                <li>Cocok untuk pendidikan, pelatihan, survei internal, dan pendataan</li>
                <li>Tidak memerlukan instalasi di sisi responden</li>
                <li>Data tersimpan terstruktur dan siap diekspor ke Excel</li>
              </ul>
            </div>
            <div className="tp-about-card">
              <div className="tp-about-card-inner">
                <div className="tp-about-card-head">
                  <span className="tp-about-card-dot" />
                  <span className="tp-about-card-title">Alur Form4x</span>
                </div>
                <ol className="tp-about-steps">
                  <li><strong>Susun</strong><span>Tambah pertanyaan, atur tipe, dan tetapkan kunci jawaban</span></li>
                  <li><strong>Atur</strong><span>Kelola status, jadwal, dan kontrol pengisian di Setelan</span></li>
                  <li><strong>Bagikan</strong><span>Sebarkan tautan atau QR, responden dapat mengisi tanpa akun</span></li>
                  <li><strong>Analisis</strong><span>Pantau skor, durasi, dan distribusi jawaban secara real-time</span></li>
                </ol>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* FITUR — simetris 3x2 */}
      <section className="tp-features">
        <div className="tp-section-inner">
          <div className="tp-section-header">
            <span className="tp-section-kicker">Fitur Utama</span>
            <h2 className="tp-section-title">Fungsionalitas Lengkap dalam Satu Tempat</h2>
            <p className="tp-section-desc">Setiap fitur disusun agar saling melengkapi, tanpa elemen berlebihan.</p>
          </div>
          <div className="tp-features-grid">
            {features.map((f, i) => (
              <div key={i} className="tp-feature-card">
                <div className="tp-feature-icon">
                  <svg width="22" height="22" fill="none" viewBox="0 0 24 24" stroke="#0B76D4" strokeWidth={1.9}><path strokeLinecap="round" strokeLinejoin="round" d={f.icon} /></svg>
                </div>
                <h3 className="tp-feature-title">{f.title}</h3>
                <p className="tp-feature-desc">{f.desc}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* NILAI — simetris 4 kolom */}
      <section className="tp-values">
        <div className="tp-section-inner">
          <div className="tp-values-grid">
            {values.map((v, i) => (
              <div key={i} className="tp-value-card">
                <h3 className="tp-value-title">{v.title}</h3>
                <p className="tp-value-desc">{v.desc}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* TIM PENGEMBANG — simetris 3x2, clean */}
      <section className="tp-team">
        <div className="tp-section-inner">
          <div className="tp-section-header">
            <span className="tp-section-kicker">Tim Pengembang</span>
            <h2 className="tp-section-title">Dikembangkan oleh Tim Form4x</h2>
            <p className="tp-section-desc">Setiap peran berkontribusi pada keseluruhan pengalaman aplikasi.</p>
          </div>
          <div className="tp-team-grid">
            {team.map((m, i) => (
              <div key={i} className="tp-team-card">
                <div className="tp-team-avatar">{m.initials}</div>
                <h3 className="tp-team-name">{m.name}</h3>
                <p className="tp-team-role">{m.role}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* CTA — simetris */}
      <section className="tp-cta">
        <div className="tp-cta-inner">
          <h2 className="tp-cta-title">Siap Membuat Formulir Pertama Anda?</h2>
          <p className="tp-cta-sub">Mulai dari template atau impor Word, bagikan dalam hitungan menit.</p>
          <Link to="/auth" className="tp-btn-cta">Buat Form Sekarang</Link>
        </div>
      </section>

      <footer className="hp-footer">
        <div className="hp-footer-inner">
          <div className="hp-footer-brand">Form4x</div>
          <p className="hp-footer-copy">© 2026 Form4x. All rights reserved.</p>
        </div>
      </footer>
    </div>
  )
}

export default TentangPage
