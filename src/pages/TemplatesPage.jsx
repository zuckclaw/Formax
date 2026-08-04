import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { deleteTemplate, getTemplates } from '../services/formService'

const TemplatesPage = () => {
  const [templates, setTemplates] = useState([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const loadTemplates = async () => {
      try {
        const response = await getTemplates()
        setTemplates(response)
      } catch (error) {
        console.error('Gagal mengambil template:', error)
      } finally {
        setLoading(false)
      }
    }

    loadTemplates()
  }, [])

  return (
    <div className="page-shell">
      <aside className="sidebar">
        <div className="brand">Formax</div>

        <nav className="nav">
          <Link to="/dashboard" className="nav-item">Dashboard</Link>
          <Link to="/forms" className="nav-item">Forms</Link>
          <Link to="/templates" className="nav-item active">Template</Link>
          <Link to="/builder" className="nav-item">Form Builder</Link>
        </nav>
      </aside>

      <main className="content">
        <header className="topbar">
          <div>
            <p className="welcome">Template</p>
            <h2>Kelola template form</h2>
          </div>
          <Link to="/templates/create" className="primary-btn button-link">+ Buat Template</Link>
        </header>

        <section className="list-grid">
          {loading ? (
            <p>Memuat template...</p>
          ) : (
            templates.map((template) => (
              <div key={template.id} className="card item-card">
                <div className="card-head">
                  <span className="badge">Template</span>
                  <div className="action-group compact">
                    <button className="mini-btn">Edit</button>
                    <button className="mini-btn danger-btn" onClick={() => deleteTemplate(template.id)}>Hapus</button>
                  </div>
                </div>

                <h3>{template.title}</h3>
                <p>{template.description}</p>

                <div className="meta-row">
                  <span>{template.questions ?? 0} pertanyaan</span>
                  <span>Publik</span>
                </div>
              </div>
            ))
          )}
        </section>
      </main>
    </div>
  )
}

export default TemplatesPage
