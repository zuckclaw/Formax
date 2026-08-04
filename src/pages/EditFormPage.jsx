import { useEffect, useState } from 'react'
import { Link, useNavigate, useParams } from 'react-router-dom'
import { getFormById, updateForm } from '../services/formService'

const EditFormPage = () => {
  const { formId } = useParams()
  const navigate = useNavigate()
  const [formData, setFormData] = useState({
    title: '',
    description: '',
    slug: '',
    status: 'Draft',
  })
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)
  const [message, setMessage] = useState('')

  useEffect(() => {
    const loadForm = async () => {
      try {
        const data = await getFormById(Number(formId))
        if (data) {
          setFormData({
            title: data.title || '',
            description: data.description || '',
            slug: data.slug || '',
            status: data.status || 'Draft',
          })
        }
      } catch (error) {
        console.error('Gagal memuat form untuk edit:', error)
      } finally {
        setLoading(false)
      }
    }

    loadForm()
  }, [formId])

  const handleChange = (event) => {
    const { name, value } = event.target
    setFormData((prev) => ({ ...prev, [name]: value }))
  }

  const handleSubmit = async (event) => {
    event.preventDefault()
    setSaving(true)
    setMessage('')

    try {
      const result = await updateForm(Number(formId), formData)
      setMessage(`Form "${result.title || formData.title}" berhasil diperbarui.`)
      setTimeout(() => navigate('/forms'), 500)
    } catch (error) {
      setMessage('Gagal memperbarui form.')
    } finally {
      setSaving(false)
    }
  }

  if (loading) {
    return <div className="page-shell"><main className="content"><p>Memuat form...</p></main></div>
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
            <h2>Edit Form</h2>
          </div>
        </header>

        <section className="card form-card">
          <form onSubmit={handleSubmit} className="form-panel">
            <label>
              Judul form
              <input type="text" name="title" value={formData.title} onChange={handleChange} required />
            </label>

            <label>
              Deskripsi
              <textarea name="description" value={formData.description} onChange={handleChange} rows="4" />
            </label>

            <label>
              Slug
              <input type="text" name="slug" value={formData.slug} onChange={handleChange} />
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
              <button type="submit" className="primary-btn" disabled={saving}>
                {saving ? 'Menyimpan...' : 'Simpan Perubahan'}
              </button>
              <Link to="/forms" className="secondary-link">Kembali</Link>
            </div>
          </form>
        </section>
      </main>
    </div>
  )
}

export default EditFormPage
