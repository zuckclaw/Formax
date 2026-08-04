import { useState } from 'react'
import { Link } from 'react-router-dom'
import { createForm } from '../services/formService'

const CreateFormPage = () => {
  const [formData, setFormData] = useState({
    title: '',
    description: '',
    slug: '',
    status: 'Draft',
  })
  const [loading, setLoading] = useState(false)
  const [message, setMessage] = useState('')

  const handleChange = (event) => {
    const { name, value } = event.target
    setFormData((prev) => ({ ...prev, [name]: value }))
  }

  const handleSubmit = async (event) => {
    event.preventDefault()
    setLoading(true)
    setMessage('')

    try {
      const result = await createForm(formData)
      setMessage(`Form "${result.title || formData.title}" berhasil dibuat.`)
      setFormData({ title: '', description: '', slug: '', status: 'Draft' })
    } catch (error) {
      setMessage('Gagal membuat form.')
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
            <p className="welcome">Form</p>
            <h2>Buat Form Baru</h2>
          </div>
        </header>

        <section className="card form-card">
          <form onSubmit={handleSubmit} className="form-panel">
            <label>
              Judul form
              <input
                type="text"
                name="title"
                value={formData.title}
                onChange={handleChange}
                placeholder="Masukkan judul form"
                required
              />
            </label>

            <label>
              Deskripsi
              <textarea
                name="description"
                value={formData.description}
                onChange={handleChange}
                placeholder="Deskripsi singkat"
                rows="4"
              />
            </label>

            <label>
              Slug
              <input
                type="text"
                name="slug"
                value={formData.slug}
                onChange={handleChange}
                placeholder="contoh: survei-kepuasan"
              />
            </label>

            <label>
              Status
              <select name="status" value={formData.status} onChange={handleChange}>
                <option value="Draft">Draft</option>
                <option value="Published">Published</option>
              </select>
            </label>

            {message ? <div className="success-box">{message}</div> : null}

            <div className="form-actions">
              <button type="submit" className="primary-btn" disabled={loading}>
                {loading ? 'Menyimpan...' : 'Simpan Form'}
              </button>
              <Link to="/forms" className="secondary-link">Kembali</Link>
            </div>
          </form>
        </section>
      </main>
    </div>
  )
}

export default CreateFormPage
