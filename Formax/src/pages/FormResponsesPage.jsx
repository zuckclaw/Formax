import { useEffect, useState } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import { getFormResponses, getFormById } from '../services/formService'
import MainLayout from '../components/MainLayout'

const escapeCsvValue = (value) => {
  const safeValue = value == null ? '' : String(value)
  if (safeValue.includes(',') || safeValue.includes('"') || safeValue.includes('\n')) {
    return `"${safeValue.replace(/"/g, '""')}"`
  }
  return safeValue
}

// Sample respondents data matching Screenshot 2 (Section 5) & Screenshot 3 (Section 6)
const sampleRespondents = [
  {
    id: 101,
    name: 'andi pratama',
    displayName: 'Andi Pratama',
    email: 'andi.pratama@example.com',
    time: 'Hari ini, 09:42 WIB',
    type: 'Otomatis',
    initial: 'A',
    avatarBg: '#2563eb', // Vibrant blue
    answers: [
      { id: 1, question: '1. Departemen Anda?', answer: 'Marketing' },
      { id: 2, question: '2. Tingkat Kepuasan?', answer: 'Puas' },
      { id: 3, question: '3. Masukan untuk tim?', answer: 'Aplikasi sangat mudah digunakan dan sangat membantu pekerjaan saya sehari-hari.' },
    ],
  },
  {
    id: 102,
    name: 'budi santoso',
    displayName: 'Budi Santoso',
    email: 'budi.santoso@example.com',
    time: 'Kemarin, 15:20 WIB',
    type: 'Manual',
    initial: 'B',
    avatarBg: '#adc0d1', // Soft blue
    answers: [
      { id: 1, question: '1. Departemen Anda?', answer: 'Engineering' },
      { id: 2, question: '2. Tingkat Kepuasan?', answer: 'Sangat Puas' },
      { id: 3, question: '3. Masukan untuk tim?', answer: 'Fitur form builder & timer-nya sangat bagus!' },
    ],
  },
  {
    id: 103,
    name: 'citra lestar',
    displayName: 'Citra Lestari',
    email: 'citra.lestari@example.com',
    time: '12 Okt 2023, 11:05 WIB',
    type: 'Otomatis',
    initial: 'C',
    avatarBg: '#475569', // Dark slate
    answers: [
      { id: 1, question: '1. Departemen Anda?', answer: 'Human Resources' },
      { id: 2, question: '2. Tingkat Kepuasan?', answer: 'Puas' },
      { id: 3, question: '3. Masukan untuk tim?', answer: 'Harap pertahankan kemudahan navigasinya.' },
    ],
  },
]

const FormResponsesPage = () => {
  const { formId } = useParams()
  const navigate = useNavigate()
  const [form, setForm] = useState(null)
  const [loading, setLoading] = useState(true)

  // Selected Respondent for Section 6 Detail View
  const [selectedRespondent, setSelectedRespondent] = useState(null)

  useEffect(() => {
    const loadData = async () => {
      try {
        const formData = await getFormById(formId)
        setForm(formData)
      } catch (error) {
        console.error('Gagal mengambil data form:', error)
      } finally {
        setLoading(false)
      }
    }

    loadData()
  }, [formId])

  const handleExportCsv = () => {
    const header = ['ID', 'Nama', 'Email', 'Waktu Pengiriman', 'Tipe', 'Departemen', 'Tingkat Kepuasan', 'Masukan']
    const rows = sampleRespondents.map((r) => [
      r.id,
      r.name,
      r.email,
      r.time,
      r.type,
      r.answers[0]?.answer || '',
      r.answers[1]?.answer || '',
      r.answers[2]?.answer || '',
    ])

    const csv = [header, ...rows].map((row) => row.map(escapeCsvValue).join(',')).join('\n')
    const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' })
    const url = URL.createObjectURL(blob)
    const link = document.createElement('a')
    link.href = url
    link.setAttribute('download', `hasil-respons-form-${formId || '1'}.csv`)
    document.body.appendChild(link)
    link.click()
    link.remove()
    URL.revokeObjectURL(url)
  }

  // =========================================================================
  // VIEW 2: DETAIL RESPONS (SECTION 6 - MATCHING SCREENSHOT 3)
  // =========================================================================
  if (selectedRespondent) {
    return (
      <MainLayout>
        <div className="detail-respons-container">
          {/* Header Bar Detail View */}
          <div className="detail-top-nav">
            <button
              className="back-btn"
              onClick={() => setSelectedRespondent(null)}
              title="Kembali ke Daftar Respons"
            >
              <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
                <polyline points="15 18 9 12 15 6" />
              </svg>
            </button>
            <span className="detail-nav-title">Detail Jawaban Responden</span>
          </div>

          <div className="detail-respons-layout">
            {/* Left Card: Respondent Profile */}
            <div className="respondent-profile-card">
              <h3 className="profile-card-name">{selectedRespondent.displayName}</h3>
              <p className="profile-card-email">{selectedRespondent.email}</p>

              <div className="profile-card-section">
                <span className="profile-sub-label">WAKTU PENGIRIMAN</span>
                <div className="profile-sub-value">
                  <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                    <circle cx="12" cy="12" r="10" />
                    <polyline points="12 6 12 12 16 14" />
                  </svg>
                  <span>{selectedRespondent.time}</span>
                </div>
              </div>

              <div className="profile-card-section">
                <span className="profile-sub-label">STATUS PENILAIAN</span>
                <div className="profile-badge-pill">
                  <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                    <circle cx="12" cy="12" r="10" />
                    <polyline points="12 6 12 12 16 14" />
                  </svg>
                  <span>{selectedRespondent.type}</span>
                </div>
              </div>
            </div>

            {/* Right Panel: Detail Respons Questions & Answers */}
            <div className="detail-answers-panel">
              <h2 className="detail-section-title">Detail Respons</h2>

              <div className="answers-cards-list">
                {selectedRespondent.answers.map((item) => (
                  <div key={item.id} className="answer-detail-card">
                    <h4 className="answer-q-title">{item.question}</h4>
                    <div className="answer-value-box">
                      {item.answer}
                    </div>
                  </div>
                ))}
              </div>
            </div>
          </div>
        </div>
      </MainLayout>
    )
  }

  // =========================================================================
  // VIEW 1: HASIL RESPONS LIST (SECTION 5 - MATCHING SCREENSHOT 2)
  // =========================================================================
  return (
    <MainLayout>
      <div className="responses-view">
        {/* Header Section */}
        <div className="responses-header">
          <div className="header-left">
            <button className="back-btn" onClick={() => navigate('/history')} title="Kembali ke History">
              <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
                <polyline points="15 18 9 12 15 6" />
              </svg>
            </button>
            <div className="header-text">
              <h2 className="responses-title">Hasil Respons</h2>
              <p className="responses-subtitle">{form?.title || 'Formulir Pendaftaran Acara Tahunan'}</p>
            </div>
          </div>

          <button
            type="button"
            className="btn-export-csv"
            onClick={handleExportCsv}
          >
            Export CSV
          </button>
        </div>

        {/* Top 3 Stat Cards Row */}
        <div className="stats-row">
          <div className="stat-card">
            <div className="stat-icon-wrapper blue">
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
                <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" />
                <circle cx="9" cy="7" r="4" />
                <path d="M23 21v-2a4 4 0 0 0-3-3.87" />
                <path d="M16 3.13a4 4 0 0 1 0 7.75" />
              </svg>
              <span className="stat-label">Total Respons</span>
            </div>
            <div className="stat-number">342</div>
          </div>

          <div className="stat-card">
            <div className="stat-icon-wrapper gray">
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
                <circle cx="12" cy="12" r="10" />
                <polyline points="12 6 12 12 16 14" />
              </svg>
              <span className="stat-label">Waktu Rata-rata</span>
            </div>
            <div className="stat-number">2m 14s</div>
          </div>

          <div className="stat-card">
            <div className="stat-icon-wrapper gray">
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
                <polyline points="22 12 18 12 15 21 9 3 6 12 2 12" />
              </svg>
              <span className="stat-label">Respons Hari Ini</span>
            </div>
            <div className="stat-number">12</div>
          </div>
        </div>

        {/* Section: Siapa yang Mengisi Ini */}
        <div className="list-section">
          <h3 className="section-title">Siapa yang Mengisi Ini</h3>

          <div className="responder-list-card">
            {loading ? (
              <p className="responses-empty" style={{ padding: '24px' }}>Memuat respons...</p>
            ) : (
              <div className="responder-rows">
                {sampleRespondents.map((resp) => (
                  <div key={resp.id} className="responder-row">
                    <div className="responder-info">
                      <div className="responder-avatar" style={{ backgroundColor: resp.avatarBg }}>
                        {resp.initial}
                      </div>
                      <div className="responder-details">
                        <h4 className="responder-name">{resp.name}</h4>
                        <p className="responder-time">{resp.time}</p>
                      </div>
                    </div>
                    <div className="responder-actions">
                      <div className={`badge ${resp.type === 'Otomatis' ? 'badge-auto' : 'badge-manual'}`}>
                        {resp.type === 'Otomatis' ? (
                          <>
                            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
                              <circle cx="12" cy="12" r="10" />
                              <polyline points="12 6 12 12 16 14" />
                            </svg>
                            <span>Otomatis</span>
                          </>
                        ) : (
                          <>
                            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
                              <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2" />
                              <circle cx="12" cy="7" r="4" />
                            </svg>
                            <span>Manual</span>
                          </>
                        )}
                      </div>
                      <button
                        className="btn-open-detail"
                        onClick={() => setSelectedRespondent(resp)}
                      >
                        Buka
                      </button>
                    </div>
                  </div>
                ))}
              </div>
            )}

            <div className="load-more-container">
              <button className="btn-load-more">Muat Lebih Banyak</button>
            </div>
          </div>
        </div>
      </div>
    </MainLayout>
  )
}

export default FormResponsesPage
