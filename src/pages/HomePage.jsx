import { Link } from 'react-router-dom'

const features = [
  {
    icon: '✦',
    title: 'Builder cepat',
    description: 'Buat form dengan pertanyaan yang mudah diatur dan diubah sesuai kebutuhan.',
  },
  {
    icon: '▣',
    title: 'Template siap pakai',
    description: 'Gunakan template yang relevan untuk survei, pendaftaran, atau evaluasi.',
  },
  {
    icon: '↗',
    title: 'Respon terukur',
    description: 'Pantau progres, lihat jawaban, dan ekspor data CSV dengan mudah.',
  },
]

const HomePage = () => {
  return (
    <div className="home-shell">
      <div className="home-hero">
        <header className="home-nav">
          <div className="home-brand">Formax</div>
          <div className="home-actions">
            <Link to="/login" className="secondary-link-button">Masuk</Link>
            <Link to="/register" className="primary-btn button-link">Daftar</Link>
          </div>
        </header>

        <section className="home-banner">
          <div className="hero-copy">
            <span className="home-eyebrow">Form management</span>
            <h1>Buat form, survey, dan feedback dalam satu dashboard.</h1>
            <p>
              Formax membantu tim mengelola form dari pembuatan pertanyaan, template, hingga respon pengguna
              dan laporan performa tanpa ribet.
            </p>
            <div className="hero-actions">
              <Link to="/register" className="primary-btn button-link">Mulai sekarang</Link>
              <Link to="/login" className="secondary-link-button">Saya sudah punya akun</Link>
            </div>
          </div>

          <div className="hero-card">
            <div className="hero-panel">
              <div className="mini-stat">
                <span>Total form</span>
                <strong>128</strong>
              </div>
              <div className="mini-stat">
                <span>Submission</span>
                <strong>4.2k</strong>
              </div>
              <div className="mini-stat">
                <span>Completion rate</span>
                <strong>86%</strong>
              </div>
            </div>
          </div>
        </section>
      </div>

      <section className="home-grid">
        {features.map((feature) => (
          <article key={feature.title} className="home-feature">
            <div className="feature-icon">{feature.icon}</div>
            <h3>{feature.title}</h3>
            <p>{feature.description}</p>
          </article>
        ))}
      </section>
    </div>
  )
}

export default HomePage
