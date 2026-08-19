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

  const filteredForms = forms.filter((f) =>
    f.title?.toLowerCase().includes(searchQuery.toLowerCase())
  )

  return (
    <MainLayout searchQuery={searchQuery} setSearchQuery={setSearchQuery}>
      <div className="dashboard-view">
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
