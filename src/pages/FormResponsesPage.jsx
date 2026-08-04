import { useEffect, useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import { getFormResponses } from '../services/formService'

const escapeCsvValue = (value) => {
  const safeValue = value == null ? '' : String(value)
  if (safeValue.includes(',') || safeValue.includes('"') || safeValue.includes('\n')) {
    return `"${safeValue.replace(/"/g, '""')}"`
  }

  return safeValue
}

const FormResponsesPage = () => {
  const { formId } = useParams()
  const [responses, setResponses] = useState([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const loadResponses = async () => {
      try {
        const data = await getFormResponses(Number(formId))
        setResponses(data)
      } catch (error) {
        console.error('Gagal mengambil respon:', error)
      } finally {
        setLoading(false)
      }
    }

    loadResponses()
  }, [formId])

  const handleExportCsv = () => {
    if (!responses.length) return

    const allKeys = Array.from(
      new Set(responses.flatMap((response) => Object.keys(response.answers || {}))),
    )

    const header = ['id', 'submitted_at', ...allKeys]
    const rows = responses.map((response) => {
      const answerMap = response.answers || {}
      return [
        response.id,
        response.submitted_at || '',
        ...allKeys.map((key) => {
          const value = answerMap[key]
          if (Array.isArray(value)) return value.join(' | ')
          return value ?? ''
        }),
      ]
    })

    const csv = [header, ...rows].map((row) => row.map(escapeCsvValue).join(',')).join('\n')
    const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' })
    const url = URL.createObjectURL(blob)
    const link = document.createElement('a')
    link.href = url
    link.setAttribute('download', `form-responses-${formId}.csv`)
    document.body.appendChild(link)
    link.click()
    link.remove()
    URL.revokeObjectURL(url)
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
            <p className="welcome">Responses</p>
            <h2>Daftar jawaban form</h2>
          </div>
          <button type="button" className="primary-btn" onClick={handleExportCsv} disabled={loading || !responses.length}>
            Export CSV
          </button>
        </header>

        <section className="table-panel card">
          {loading ? (
            <p>Memuat respon...</p>
          ) : responses.length === 0 ? (
            <p>Belum ada respon.</p>
          ) : (
            <table>
              <thead>
                <tr>
                  <th>ID</th>
                  <th>Waktu</th>
                  <th>Jawaban</th>
                </tr>
              </thead>
              <tbody>
                {responses.map((response) => (
                  <tr key={response.id}>
                    <td>{response.id}</td>
                    <td>{response.submitted_at || 'Baru saja'}</td>
                    <td>{JSON.stringify(response.answers || {})}</td>
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

export default FormResponsesPage
