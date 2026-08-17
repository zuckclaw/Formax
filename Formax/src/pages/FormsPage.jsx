import { useEffect, useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { deleteForm, getForms } from '../services/formService'

const FormsPage = () => {
  const navigate = useNavigate()
  const [forms, setForms] = useState([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const loadForms = async () => {
      try {
        const response = await getForms()
        setForms(response)
      } catch (error) {
        console.error('Gagal mengambil form:', error)
      } finally {
        setLoading(false)
      }
    }

    loadForms()
  }, [])

  const handleDelete = async (formId) => {
    if (!window.confirm('Yakin ingin menghapus form ini?')) return

    try {
      await deleteForm(formId)
      setForms((prev) => prev.filter((form) => form.id !== formId))
    } catch (error) {
      console.error('Gagal menghapus form:', error)
    }
  }

  return (
    <div className="page-shell">
      <aside className="sidebar">
        <div className="brand">Formax</div>

        <nav className="nav">
          <Link to="/dashboard" className="nav-item">Dashboard</Link>
          <Link to="/forms" className="nav-item active">Forms</Link>
          <Link to="/templates" className="nav-item">Template</Link>
          <Link to="/builder" className="nav-item">Form Builder</Link>
        </nav>
      </aside>

      <main className="content">
        <header className="topbar">
          <div>
            <p className="welcome">Form</p>
            <h2>Daftar form aktif</h2>
          </div>
          <Link to="/forms/create" className="primary-btn button-link">+ Buat Form</Link>
        </header>

        <section className="table-panel card">
          {loading ? (
            <p>Memuat data form...</p>
          ) : (
            <table>
              <thead>
                <tr>
                  <th>Judul</th>
                  <th>Slug</th>
                  <th>Status</th>
                  <th>Respon</th>
                  <th>Aksi</th>
                </tr>
              </thead>
              <tbody>
                {forms.map((form) => (
                  <tr key={form.id}>
                    <td>{form.title}</td>
                    <td>{form.slug}</td>
                    <td>
                      <span className={`status ${form.status === 'Published' ? 'published' : 'draft'}`}>
                        {form.status}
                      </span>
                    </td>
                    <td>{form.responses ?? 0}</td>
                    <td>
                      <div className="action-group">
                        <button type="button" className="mini-btn" onClick={() => navigate(`/forms/${form.id}`)}>Lihat</button>
                        <button type="button" className="mini-btn" onClick={() => navigate(`/forms/${form.id}/edit`)}>Edit</button>
                        <button type="button" className="mini-btn danger-btn" onClick={() => handleDelete(form.id)}>Hapus</button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </section>
      </main>
    </div>
  )
}

export default FormsPage
