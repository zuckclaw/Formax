import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import MainLayout from '../components/MainLayout'
import FormCard from '../components/FormCard'
import { getBuiltInTemplates, getForms } from '../services/formService'

const DashboardPage = () => {
  const navigate = useNavigate()
  const [forms, setForms] = useState([])
  const [searchQuery, setSearchQuery] = useState('')
  const [loading, setLoading] = useState(true)

  const [joinLink, setJoinLink] = useState('')

  const builtInTemplates = getBuiltInTemplates()

  useEffect(() => {
    loadDashboardForms()
  }, [])

  const loadDashboardForms = async () => {
    try {
      const data = await getForms()
      setForms(data)
    } catch (err) {
      console.error('Failed to load forms:', err)
    } finally {
      setLoading(false)
    }
  }

  const handleDeleteForm = (deletedId) => {
    setForms((prev) => prev.filter((f) => String(f.id) !== String(deletedId)))
  }

  const handleJoinForm = () => {
    if (!joinLink.trim()) return

    try {
      // Validate if it's a URL or just an ID
      let path = joinLink.trim()
      
      try {
        const urlObj = new URL(path)
        path = urlObj.pathname
      } catch (e) {
        // Not a valid URL, might be just a path or ID
      }
      
      // If the user pasted an ID (e.g. 1722883392)
      if (!isNaN(path) && path.length > 0) {
        navigate(`/forms/public/${path}`)
        return
      }
      
      // If the user pasted a path that includes /forms/
      if (path.includes('/forms/')) {
        navigate(path)
      } else {
        alert('Format link form tidak valid. Pastikan link mengandung /forms/')
      }
    } catch (err) {
      alert('Terjadi kesalahan saat memproses link.')
    }
  }

  const filteredForms = forms.filter((f) =>
    f.title?.toLowerCase().includes(searchQuery.toLowerCase())
  )

  return (
    <MainLayout searchQuery={searchQuery} setSearchQuery={setSearchQuery}>
      <div className="dashboard-view">
        {/* Row Top: Join Form Section */}
        <section className="join-form-section" style={{ marginBottom: '28px' }}>
          <h2 className="section-heading" style={{ marginBottom: '12px' }}>Bergabung ke Form</h2>
          <div style={{ display: 'flex', gap: '12px', alignItems: 'center' }}>
            <div className="search-box" style={{ flex: 1, maxWidth: '600px' }}>
              <svg className="search-icon" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <path d="M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71"></path>
                <path d="M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71"></path>
              </svg>
              <input
                type="text"
                className="search-input"
                placeholder="Masukkan link atau ID form..."
                value={joinLink}
                onChange={(e) => setJoinLink(e.target.value)}
                onKeyDown={(e) => e.key === 'Enter' && handleJoinForm()}
              />
            </div>
            <button
              onClick={handleJoinForm}
              style={{
                backgroundColor: '#146EE3',
                color: 'white',
                border: 'none',
                padding: '10px 24px',
                borderRadius: '999px',
                fontWeight: '600',
                cursor: 'pointer',
                transition: 'background-color 0.2s',
                height: '42px'
              }}
              onMouseOver={(e) => (e.target.style.backgroundColor = '#0f52b3')}
              onMouseOut={(e) => (e.target.style.backgroundColor = '#146EE3')}
            >
              Masuk
            </button>
          </div>
        </section>

        {/* Row Top: Built-in Templates & Create Card */}
        <section className="top-templates-section">
          <div className="template-cards-grid">
            {/* Card Create New Template */}
            <div
              className="create-template-dashed-card"
              onClick={() => navigate('/builder')}
            >
              <div className="plus-circle-icon">
                <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                  <circle cx="12" cy="12" r="10" />
                  <line x1="12" y1="8" x2="12" y2="16" />
                  <line x1="8" y1="12" x2="16" y2="12" />
                </svg>
              </div>
              <span className="create-card-label">Create New Template</span>
            </div>

            {/* Starter Built-in Templates */}
            {builtInTemplates.map((template) => (
              <FormCard
                key={template.id}
                form={template}
                mode="template-builtin"
              />
            ))}
          </div>
        </section>

        {/* Row Bottom: Recent History */}
        <section className="recent-history-section">
          <h2 className="section-heading">Recent History</h2>

          {loading ? (
            <p className="loading-text">Memuat riwayat form...</p>
          ) : filteredForms.length === 0 ? (
            <div className="empty-state">
              <p>Belum ada form yang cocok. Ketuk "+ Create New Template" untuk membuat baru!</p>
            </div>
          ) : (
            <div className="history-cards-grid">
              {filteredForms.map((form) => (
                <FormCard
                  key={form.id}
                  form={form}
                  mode="recent-history"
                  onDeleteSuccess={handleDeleteForm}
                />
              ))}
            </div>
          )}
        </section>
      </div>
    </MainLayout>
  )
}

export default DashboardPage
