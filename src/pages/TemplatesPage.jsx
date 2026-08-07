import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import MainLayout from '../components/MainLayout'
import FormCard from '../components/FormCard'
import { getBuiltInTemplates, getTemplates } from '../services/formService'

const TemplatesPage = () => {
  const navigate = useNavigate()
  const [myTemplates, setMyTemplates] = useState([])
  const [searchQuery, setSearchQuery] = useState('')
  const [loading, setLoading] = useState(true)

  const builtInTemplates = getBuiltInTemplates()

  useEffect(() => {
    loadTemplatesData()
  }, [])

  const loadTemplatesData = async () => {
    try {
      const data = await getTemplates()
      setMyTemplates(data)
    } catch (err) {
      console.error('Failed to load templates:', err)
    } finally {
      setLoading(false)
    }
  }

  const handleDeleteTemplate = (deletedId) => {
    setMyTemplates((prev) => prev.filter((t) => String(t.id) !== String(deletedId)))
  }

  const filteredMyTemplates = myTemplates.filter((t) =>
    t.title?.toLowerCase().includes(searchQuery.toLowerCase())
  )

  return (
    <MainLayout searchQuery={searchQuery} setSearchQuery={setSearchQuery}>
      <div className="templates-view">
        {/* Section 1: Built-in Templates */}
        <section className="template-group-section">
          <div className="group-header">
            <h2 className="section-heading">Built-in Templates</h2>
            <button className="view-all-link" onClick={() => navigate('/builder')}>View All</button>
          </div>

          <div className="template-cards-grid">
            {builtInTemplates.map((template) => (
              <FormCard
                key={template.id}
                form={template}
                mode="template-builtin"
              />
            ))}
          </div>
        </section>

        {/* Section 2: My Templates */}
        <section className="template-group-section mt-6">
          <h2 className="section-heading">My Templates</h2>

          <div className="history-cards-grid">
            {/* Create New Template Card */}
            <div
              className="create-template-dashed-card"
              onClick={() => navigate('/builder')}
            >
              <div className="plus-circle-icon">
                <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                  <circle cx="12" cy="12" r="10" />
                  <line x1="12" y1="8" x2="16" />
                  <line x1="8" y1="12" x2="16" y2="12" />
                </svg>
              </div>
              <span className="create-card-label">Create New Template</span>
            </div>

            {loading ? (
              <p className="loading-text">Memuat template pengguna...</p>
            ) : (
              filteredMyTemplates.map((template) => (
                <FormCard
                  key={template.id}
                  form={{
                    ...template,
                    updatedAt: template.updatedAt || 'Updated 2 days ago',
                  }}
                  mode="my-templates"
                  onDeleteSuccess={handleDeleteTemplate}
                />
              ))
            )}
          </div>
        </section>
      </div>
    </MainLayout>
  )
}

export default TemplatesPage
