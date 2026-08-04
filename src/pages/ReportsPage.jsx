import { Link } from 'react-router-dom'

const reportStats = [
  { title: 'Total Respon', value: '1,248', change: '+18.2%' },
  { title: 'Completion Rate', value: '86%', change: '+5.4%' },
  { title: 'Avg. Time', value: '4m 12s', change: '-12s' },
]

const reports = [
  { label: 'Survey Kepuasan Pelanggan', value: 78, color: '#4f46e5' },
  { label: 'Form Webinar', value: 65, color: '#10b981' },
  { label: 'Feedback Internal', value: 92, color: '#f59e0b' },
]

const ReportsPage = () => {
  return (
    <div className="page-shell">
      <aside className="sidebar">
        <div className="brand">Formax</div>

        <nav className="nav">
          <Link to="/dashboard" className="nav-item">Dashboard</Link>
          <Link to="/forms" className="nav-item">Forms</Link>
          <Link to="/templates" className="nav-item">Template</Link>
          <Link to="/builder" className="nav-item">Form Builder</Link>
          <Link to="/reports" className="nav-item active">Reports</Link>
        </nav>
      </aside>

      <main className="content">
        <header className="topbar">
          <div>
            <p className="welcome">Analytics</p>
            <h2>Reports & performance</h2>
          </div>
        </header>

        <section className="summary-grid">
          {reportStats.map((stat) => (
            <div key={stat.title} className="summary-card">
              <p>{stat.title}</p>
              <h3>{stat.value}</h3>
              <span>{stat.change} vs last month</span>
            </div>
          ))}
        </section>

        <section className="panel">
          <div className="panel-header">
            <h3>Completion by form</h3>
          </div>

          <div className="report-list">
            {reports.map((report) => (
              <div key={report.label} className="report-row">
                <div className="report-label-row">
                  <span>{report.label}</span>
                  <strong>{report.value}%</strong>
                </div>
                <div className="progress-track">
                  <div className="progress-bar" style={{ width: `${report.value}%`, background: report.color }} />
                </div>
              </div>
            ))}
          </div>
        </section>
      </main>
    </div>
  )
}

export default ReportsPage
