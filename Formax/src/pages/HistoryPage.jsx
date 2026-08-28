import { useEffect, useState } from 'react'
import MainLayout from '../components/MainLayout'
import FormCard from '../components/FormCard'
import { getForms } from '../services/formService'

const HistoryPage = () => {
  const [historyForms, setHistoryForms] = useState([])
  const [searchQuery, setSearchQuery] = useState('')
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    loadHistory()
  }, [])

  async function loadHistory() {
    try {
      const data = await getForms()
      setHistoryForms(data)
    } catch (err) {
      console.error('Failed to load history forms:', err)
    } finally {
      setLoading(false)
    }
  }

  const handleDeleteForm = (deletedId) => {
    setHistoryForms((prev) => prev.filter((f) => String(f.id) !== String(deletedId)))
  }

  const filteredForms = historyForms.filter((f) =>
    f.title?.toLowerCase().includes(searchQuery.toLowerCase())
  )

  return (
    <MainLayout searchQuery={searchQuery} setSearchQuery={setSearchQuery}>
      <div className="history-view">
        {loading ? (
          <p className="loading-text">Memuat riwayat form...</p>
        ) : filteredForms.length === 0 ? (
          <div className="empty-state">
            <p>Tidak ada riwayat form yang ditemukan.</p>
          </div>
        ) : (
          <div className="history-cards-grid">
            {filteredForms.map((form) => (
              <FormCard
                key={form.id}
                form={form}
                mode="history-page"
                onDeleteSuccess={handleDeleteForm}
              />
            ))}
          </div>
        )}
      </div>
    </MainLayout>
  )
}

export default HistoryPage
