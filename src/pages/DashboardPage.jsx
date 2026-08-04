import { Link } from 'react-router-dom'
import { useAuth } from '../context/AuthContext'

const summaryCards = [
  { title: 'Total Form', value: '12', subtitle: 'Aktif & draft' },
  { title: 'Template', value: '8', subtitle: 'Siap dipakai' },
  { title: 'Submission', value: '420', subtitle: 'Respon masuk' },
]

const recentForms = [
  { name: 'Survey Kepuasan Pelanggan', status: 'Published', updated: '2 jam lalu' },
  { name: 'Form Pendaftaran Webinar', status: 'Draft', updated: '5 jam lalu' },
  { name: 'Evaluasi Kegiatan Internal', status: 'Published', updated: '1 hari lalu' },
]

const DashboardPage = () => {
  const { user, logout } = useAuth()

  return (
    <div className="dashboard-page">
      <aside className="sidebar">
        <div className="brand">Formax</div>

        <nav className="nav">
          <Link to="/dashboard" className="nav-item active">Dashboard</Link>
          <Link to="/forms" className="nav-item">Forms</Link>
          <Link to="/builder" className="nav-item">Form Builder</Link>
          <Link to="/templates" className="nav-item">Template</Link>
          <Link to="/reports" className="nav-item">Reports</Link>
        </nav>

        <button className="logout-btn" onClick={logout}>Keluar</button>
      </aside>

      <main className="content">
        <header className="topbar">
          <div>
            <p className="welcome">Selamat datang</p>
            <h2>{user?.full_name || user?.name || 'Pengguna'}</h2>
          </div>
          <Link to="/forms/create" className="primary-btn button-link">+ Buat Form</Link>
        </header>

        <section className="summary-grid">
          {summaryCards.map((card) => (
            <div key={card.title} className="summary-card">
              <p>{card.title}</p>
              <h3>{card.value}</h3>
              <span>{card.subtitle}</span>
            </div>
          ))}
        </section>

        <section className="panel">
          <div className="panel-header">
            <h3>Form Terbaru</h3>
            <Link to="/builder">Lihat semua</Link>
          </div>

          <table>
            <thead>
              <tr>
                <th>Nama Form</th>
                <th>Status</th>
                <th>Update</th>
              </tr>
            </thead>
            <tbody>
              {recentForms.map((form) => (
                <tr key={form.name}>
                  <td>{form.name}</td>
                  <td>
                    <span className={`status ${form.status === 'Published' ? 'published' : 'draft'}`}>
                      {form.status}
                    </span>
                  </td>
                  <td>{form.updated}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </section>
      </main>
    </div>
  )
}

export default DashboardPage
