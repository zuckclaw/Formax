import { useState } from 'react'
import { Link } from 'react-router-dom'
import { createTemplate } from '../services/formService'

const CreateTemplatePage = () => {
  const [formData, setFormData] = useState({
    title: '',
    description: '',
    questions: 0,
  })
  const [loading, setLoading] = useState(false)
  const [message, setMessage] = useState('')

  const handleChange = (event) => {
    const { name, value } = event.target
    setFormData((prev) => ({ ...prev, [name]: name === 'questions' ? Number(value) : value }))
  }

  const handleSubmit = async (event) => {
    event.preventDefault()
    setLoading(true)
    setMessage('')

    try {
      const result = await createTemplate(formData)
      setMessage(`Template "${result.title || formData.title}" berhasil dibuat.`)
      setFormData({ title: '', description: '', questions: 0 })
    } catch (error) {
      setMessage('Gagal membuat template.')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="page-shell">
      <aside className="sidebar">
        <div className="brand">Formax</div>

        <nav className="nav">
          <Link to="/dashboard" className="nav-item">Dashboard</Link>
          <Link to="/forms" className="nav-item">Forms</Link>
          <Link to="/templates" className="nav-item">Template</Link>
          <Link to="/builder" className="nav-item active">Form Builder</Link>
        </nav>
      </aside>

      <main className="content">
        <header className="topbar">
          <div>
            <p className="welcome">Template</p>
            <h2>Buat Template Baru</h2>
          </div>
        </header>

        <section className="card form-card">
          <form onSubmit={handleSubmit} className="form-panel">
            <label>
              Judul template
              <input
                type="text"
                name="title"
                value={formData.title}
                onChange={handleChange}
                placeholder="Masukkan judul template"
                required
              />
            </label>

            <label>
              Deskripsi
              <textarea
                name="description"
                value={formData.description}
                onChange={handleChange}
                placeholder="Deskripsi template"
                rows="4"
              />
            </label>

            <label>
              Jumlah pertanyaan
              <input
                type="number"
                min="0"
                name="questions"
                value={formData.questions}
                onChange={handleChange}
              />
            </label>

            {message ? <div className="success-box">{message}</div> : null}

            <div className="form-actions">
              <button type="submit" className="primary-btn" disabled={loading}>
                {loading ? 'Menyimpan...' : 'Simpan Template'}
              </button>
              <Link to="/templates" className="secondary-link">Kembali</Link>
            </div>
          </form>
        </section>
      </main>
    </div>
  )
}

export default CreateTemplatePage
