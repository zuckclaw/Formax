import { useEffect, useState } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import { getFormResponses, getFormById } from '../services/formService'
import MainLayout from '../components/MainLayout'
import '../Dashboard.css'

const escapeCsvValue = (value) => {
  const safeValue = value == null ? '' : String(value)
  if (safeValue.includes(',') || safeValue.includes('"') || safeValue.includes('\n')) {
    return `"${safeValue.replace(/"/g, '""')}"`
  }
  return safeValue
}

// Updated Sample respondents data matching the scoring focus
const sampleRespondents = [
  {
    id: 101,
    name: 'Andi',
    displayName: 'Andi',
    email: 'andi@email.com',
    time: '27 Aug 2026, 08:32 WIB',
    completionTime: '10:15',
    score: 90,
    type: 'Otomatis',
    initial: 'A',
    avatarBg: '#2563eb',
    answers: [
      { id: 1, question: 'Q1. Nama', answer: 'Andi' },
      { id: 2, question: 'Q2. Kelas', answer: 'XII RPL 1' },
      { id: 3, question: 'Q3. Bahasa Pemrograman Favorit?', answer: 'JavaScript' },
    ],
  },
  {
    id: 102,
    name: 'Budi',
    displayName: 'Budi',
    email: 'budi@email.com',
    time: '27 Aug 2026, 08:45 WIB',
    completionTime: '15:20',
    score: 85,
    type: 'Manual',
    initial: 'B',
    avatarBg: '#adc0d1',
    answers: [
      { id: 1, question: 'Q1. Nama', answer: 'Budi' },
      { id: 2, question: 'Q2. Kelas', answer: 'XII RPL 2' },
      { id: 3, question: 'Q3. Bahasa Pemrograman Favorit?', answer: 'Python' },
    ],
  },
  {
    id: 103,
    name: 'Citra',
    displayName: 'Citra',
    email: 'citra@email.com',
    time: '27 Aug 2026, 09:02 WIB',
    completionTime: '06:42',
    score: 95,
    type: 'Otomatis',
    initial: 'C',
    avatarBg: '#475569',
    answers: [
      { id: 1, question: 'Q1. Nama', answer: 'Citra' },
      { id: 2, question: 'Q2. Kelas', answer: 'XII RPL 2' },
      { id: 3, question: 'Q3. Bahasa Pemrograman Favorit?', answer: 'Java' },
    ],
  },
  {
    id: 104,
    name: 'Dewi',
    displayName: 'Dewi',
    email: 'dewi@email.com',
    time: '27 Aug 2026, 10:15 WIB',
    completionTime: '22:10',
    score: 65,
    type: 'Otomatis',
    initial: 'D',
    avatarBg: '#f59e0b',
    answers: [
      { id: 1, question: 'Q1. Nama', answer: 'Dewi' },
      { id: 2, question: 'Q2. Kelas', answer: 'XII TKJ 1' },
      { id: 3, question: 'Q3. Bahasa Pemrograman Favorit?', answer: 'C++' },
    ],
  },
  {
    id: 105,
    name: 'Eko',
    displayName: 'Eko',
    email: 'eko@email.com',
    time: '27 Aug 2026, 11:30 WIB',
    completionTime: '18:05',
    score: 75,
    type: 'Otomatis',
    initial: 'E',
    avatarBg: '#10b981',
    answers: [
      { id: 1, question: 'Q1. Nama', answer: 'Eko' },
      { id: 2, question: 'Q2. Kelas', answer: 'XII TKJ 2' },
      { id: 3, question: 'Q3. Bahasa Pemrograman Favorit?', answer: 'PHP' },
    ],
  },
]

// ---- Chart Helper Functions (Pure SVG) ----
const CHART_COLORS = ['#086ae3', '#10b981', '#f59e0b', '#ef4444', '#8b5cf6', '#ec4899', '#14b8a6', '#f97316']

const PieChart = ({ data, size = 200 }) => {
  const [animate, setAnimate] = useState(false)
  useEffect(() => {
    const timer = setTimeout(() => setAnimate(true), 150)
    return () => clearTimeout(timer)
  }, [])

  const total = data.reduce((sum, d) => sum + d.value, 0)
  if (total === 0) return <div style={{ textAlign: 'center', color: '#94a3b8', padding: 24 }}>Belum ada data</div>
  const radius = size / 2 - 14
  const cx = size / 2
  const cy = size / 2
  
  const { slices } = data.reduce((acc, d, i) => {
    const angle = (d.value / total) * 360
    const startAngle = acc.cumulativeAngle
    const endAngle = acc.cumulativeAngle + angle
    acc.cumulativeAngle = endAngle

    const startRad = (Math.PI / 180) * startAngle
    const endRad = (Math.PI / 180) * endAngle
    const x1 = cx + radius * Math.cos(startRad)
    const y1 = cy + radius * Math.sin(startRad)
    const x2 = cx + radius * Math.cos(endRad)
    const y2 = cy + radius * Math.sin(endRad)
    const largeArc = angle > 180 ? 1 : 0

    const pathData = angle >= 360
      ? `M ${cx} ${cy - radius} A ${radius} ${radius} 0 1 1 ${cx - 0.001} ${cy - radius} Z`
      : `M ${cx} ${cy} L ${x1} ${y1} A ${radius} ${radius} 0 ${largeArc} 1 ${x2} ${y2} Z`

    acc.slices.push(
      <path
        key={i}
        d={pathData}
        fill={CHART_COLORS[i % CHART_COLORS.length]}
        stroke="#ffffff"
        strokeWidth="3"
        style={{ 
          transition: `all 0.6s cubic-bezier(0.34, 1.56, 0.64, 1) ${i * 0.1}s`,
          transform: animate ? 'scale(1)' : 'scale(0.5)',
          transformOrigin: 'center',
          opacity: animate ? 1 : 0
        }}
      >
        <title>{d.label}: {d.value} ({((d.value / total) * 100).toFixed(1)}%)</title>
      </path>
    )
  })

  return (
    <div className="donut-chart-wrapper">
      <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`}>
        {slices}
        <circle 
          cx={cx} cy={cy} r={radius * 0.65} fill="#ffffff" 
          style={{
            transition: 'all 0.6s ease 0.3s',
            transform: animate ? 'scale(1)' : 'scale(0)',
            transformOrigin: 'center'
          }} 
        />
        <text 
          x={cx} y={cy - 5} textAnchor="middle" fontSize="24" fontWeight="800" fill="#1e293b"
          style={{ opacity: animate ? 1 : 0, transition: 'opacity 0.6s ease 0.5s' }}
        >
          {total}
        </text>
        <text 
          x={cx} y={cy + 16} textAnchor="middle" fontSize="12" fill="#64748b"
          style={{ opacity: animate ? 1 : 0, transition: 'opacity 0.6s ease 0.6s' }}
        >
          Total
        </text>
      </svg>
      <div className="donut-chart-legend">
        {data.map((d, i) => (
          <div 
            key={i} 
            className="legend-item"
            style={{
              transition: `all 0.4s ease ${0.4 + i * 0.1}s`,
              opacity: animate ? 1 : 0,
              transform: animate ? 'translateX(0)' : 'translateX(10px)'
            }}
          >
            <span className="legend-color" style={{ backgroundColor: CHART_COLORS[i % CHART_COLORS.length] }} />
            <span className="legend-label">{d.label}</span>
            <span className="legend-value">{d.value}</span>
          </div>
        ))}
      </div>
    </div>
  )
}

const VerticalBarChart = ({ data, maxValue }) => {
  const [animate, setAnimate] = useState(false)
  useEffect(() => {
    const timer = setTimeout(() => setAnimate(true), 250)
    return () => clearTimeout(timer)
  }, [])

  const max = maxValue || Math.max(...data.map(d => d.value), 1)
  const total = data.reduce((sum, d) => sum + d.value, 0) || 1

  return (
    <div className="vertical-bar-container">
      <div className="vertical-bars">
        {data.map((d, i) => {
          const heightPercent = (d.value / max) * 100;
          const labelPercent = Math.round((d.value / total) * 100);
          
          // Determine if it's the highest for styling
          const isHighest = d.value === max;

          return (
            <div 
              key={i} 
              className="bar-group" 
              title={`${d.value} orang mendapat skor ${d.label} (${labelPercent}%)`}
              style={{
                opacity: animate ? 1 : 0,
                transform: animate ? 'translateY(0)' : 'translateY(10px)',
                transition: `all 0.5s ease ${i * 0.15}s`
              }}
            >
              {/* Floating badge */}
              <div className={`bar-floating-badge ${isHighest ? 'badge-high' : 'badge-normal'}`}>
                <svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="3">
                  <polyline points="20 6 9 17 4 12"></polyline>
                </svg>
                {d.value} Org
              </div>
              
              <div className="bar-track">
                <div
                  className={`bar-fill ${isHighest ? 'fill-highest' : 'fill-normal'}`}
                  style={{
                    height: animate ? `${heightPercent}%` : '0%',
                  }}
                />
              </div>
              <span className="bar-label">{d.label}</span>
            </div>
          )
        })}
      </div>
    </div>
  )
}

const FormResponsesPage = () => {
  const { formId } = useParams()
  const navigate = useNavigate()
  const [form, setForm] = useState(null)
  const [loading, setLoading] = useState(true)

  // Selected Respondent for Detail View
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
    const header = ['ID', 'Nama', 'Email', 'Waktu Pengiriman', 'Tipe', 'Score', 'Masukan']
    const rows = sampleRespondents.map((r) => [
      r.id,
      r.name,
      r.email,
      r.time,
      r.type,
      r.score,
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

  // ---- Score & Statistik Data Computation ----
  const computeStats = () => {
    let totalScore = 0
    let highestScore = -Infinity
    let lowestScore = Infinity
    let passCount = 0
    const passThreshold = 70

    const typeCount = {}
    const scoreRanges = {
      '90-100': 0,
      '80-89': 0,
      '70-79': 0,
      '<70': 0,
    }

    sampleRespondents.forEach((resp) => {
      // Score Aggregation
      totalScore += resp.score
      if (resp.score > highestScore) highestScore = resp.score
      if (resp.score < lowestScore) lowestScore = resp.score
      if (resp.score >= passThreshold) passCount++

      // Score Ranges
      if (resp.score >= 90) scoreRanges['90-100']++
      else if (resp.score >= 80) scoreRanges['80-89']++
      else if (resp.score >= 70) scoreRanges['70-79']++
      else scoreRanges['<70']++

      // Count by type
      typeCount[resp.type] = (typeCount[resp.type] || 0) + 1
    })

    const total = sampleRespondents.length || 1
    
    const typePieData = Object.entries(typeCount).map(([label, value]) => ({ label, value }))
    const scoreBarData = Object.entries(scoreRanges).map(([label, value]) => ({ label, value }))

    return {
      typePieData,
      scoreBarData,
      totalResponses: sampleRespondents.length,
      averageScore: (totalScore / total).toFixed(1),
      highestScore: highestScore === -Infinity ? 0 : highestScore,
      lowestScore: lowestScore === Infinity ? 0 : lowestScore,
      passRate: Math.round((passCount / total) * 100),
      failedRate: Math.round(((total - passCount) / total) * 100)
    }
  }

  // =========================================================================
  // VIEW 2: DETAIL RESPONS MODAL / PAGE 
  // =========================================================================
   if (selectedRespondent) {
    const scorePercent = Math.min(selectedRespondent.score, 100)
    const circumference = 2 * Math.PI * 40
    const strokeDashoffset = circumference - (scorePercent / 100) * circumference
    const isPassed = selectedRespondent.score >= 70

    return (
      <MainLayout hideSearch={true}>
        <div className="detail-respons-container">
          {/* Top Navigation Bar */}
          <div className="detail-top-nav">
            <button
              className="back-btn"
              onClick={() => setSelectedRespondent(null)}
              title="Kembali ke Dashboard"
            >
              <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
                <polyline points="15 18 9 12 15 6" />
              </svg>
            </button>
            <div className="detail-breadcrumb">
              <span className="breadcrumb-link" onClick={() => setSelectedRespondent(null)}>Responses</span>
              <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#94a3b8" strokeWidth="2">
                <polyline points="9 6 15 12 9 18" />
              </svg>
              <span className="breadcrumb-current">{selectedRespondent.displayName}</span>
            </div>
            <div className="detail-actions">
              <button className="btn-detail-action" title="Export PDF">
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                  <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"></path>
                  <polyline points="7 10 12 15 17 10"></polyline>
                  <line x1="12" y1="15" x2="12" y2="3"></line>
                </svg>
                Export
              </button>
            </div>
          </div>

          <div className="detail-respons-layout">
            {/* Left Card: Respondent Profile */}
            <div className="respondent-profile-card detail-fade-in" style={{ animationDelay: '0.1s' }}>
              {/* Hero Header with Gradient */}
              <div className="profile-hero-header">
                <div className="profile-avatar-large" style={{ backgroundColor: selectedRespondent.avatarBg }}>
                  {selectedRespondent.initial}
                </div>
              </div>

              <div className="profile-info-body">
                <h3 className="profile-card-name">{selectedRespondent.displayName}</h3>
                <p className="profile-card-email">
                  <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                    <rect x="2" y="4" width="20" height="16" rx="2"></rect>
                    <path d="m22 7-8.97 5.7a1.94 1.94 0 0 1-2.06 0L2 7"></path>
                  </svg>
                  {selectedRespondent.email}
                </p>

                {/* Score Ring */}
                <div className="profile-score-ring-section">
                  <div className="score-ring-wrapper">
                    <svg width="100" height="100" viewBox="0 0 100 100">
                      <circle cx="50" cy="50" r="40" fill="none" stroke="#e2e8f0" strokeWidth="8" />
                      <circle
                        cx="50" cy="50" r="40" fill="none"
                        stroke={isPassed ? '#22c55e' : '#ef4444'}
                        strokeWidth="8"
                        strokeLinecap="round"
                        strokeDasharray={circumference}
                        strokeDashoffset={strokeDashoffset}
                        transform="rotate(-90 50 50)"
                        className="score-ring-progress"
                      />
                      <text x="50" y="46" textAnchor="middle" fontSize="22" fontWeight="800" fill="#0f172a">
                        {selectedRespondent.score}
                      </text>
                      <text x="50" y="62" textAnchor="middle" fontSize="10" fontWeight="600" fill="#94a3b8">
                        SCORE
                      </text>
                    </svg>
                  </div>
                  <span className={`status-badge-large ${isPassed ? 'badge-pass' : 'badge-fail'}`}>
                    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
                      {isPassed
                        ? <polyline points="20 6 9 17 4 12" />
                        : <><line x1="18" y1="6" x2="6" y2="18" /><line x1="6" y1="6" x2="18" y2="18" /></>
                      }
                    </svg>
                    {isPassed ? 'Lulus' : 'Tidak Lulus'}
                  </span>
                </div>

                {/* Info Items */}
                <div className="profile-info-items">
                  <div className="profile-info-item">
                    <div className="info-item-icon">
                      <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                        <circle cx="12" cy="12" r="10" />
                        <polyline points="12 6 12 12 16 14" />
                      </svg>
                    </div>
                    <div className="info-item-text">
                      <span className="info-item-label">Waktu Penyelesaian</span>
                      <span className="info-item-value">{selectedRespondent.completionTime}</span>
                    </div>
                  </div>
                  <div className="profile-info-item">
                    <div className="info-item-icon">
                      <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                        <rect x="3" y="4" width="18" height="18" rx="2" ry="2"></rect>
                        <line x1="16" y1="2" x2="16" y2="6"></line>
                        <line x1="8" y1="2" x2="8" y2="6"></line>
                        <line x1="3" y1="10" x2="21" y2="10"></line>
                      </svg>
                    </div>
                    <div className="info-item-text">
                      <span className="info-item-label">Submitted</span>
                      <span className="info-item-value">{selectedRespondent.time}</span>
                    </div>
                  </div>
                  <div className="profile-info-item">
                    <div className="info-item-icon">
                      <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                        <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"></path>
                        <polyline points="14 2 14 8 20 8"></polyline>
                      </svg>
                    </div>
                    <div className="info-item-text">
                      <span className="info-item-label">Tipe Penilaian</span>
                      <span className="info-item-value">{selectedRespondent.type}</span>
                    </div>
                  </div>
                </div>
              </div>
            </div>

            {/* Right Panel: Detail Answers */}
            <div className="detail-answers-panel">
              <div className="answers-panel-header detail-fade-in" style={{ animationDelay: '0.15s' }}>
                <h2 className="detail-section-title">Hasil Jawaban</h2>
                <span className="answers-count-badge">{selectedRespondent.answers.length} Pertanyaan</span>
              </div>

              <div className="answers-cards-list">
                {selectedRespondent.answers.map((item, idx) => (
                  <div
                    key={item.id}
                    className="answer-detail-card detail-fade-in"
                    style={{ animationDelay: `${0.2 + idx * 0.08}s` }}
                  >
                    <div className="answer-card-top">
                      <div className="answer-number-badge">{idx + 1}</div>
                      <h4 className="answer-q-title">{item.question}</h4>
                      <div className="answer-check-icon">
                        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#22c55e" strokeWidth="2.5">
                          <polyline points="20 6 9 17 4 12" />
                        </svg>
                      </div>
                    </div>
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
  // VIEW 1: UNIFIED ANALYTICS DASHBOARD 
  // =========================================================================
  const stats = computeStats()

  return (
    <MainLayout hideSearch={true}>
      <div className="dashboard-analytics-view">
        
        <div className="responses-header">
          <div className="header-left">
            <button className="back-btn" onClick={() => navigate('/history')} title="Kembali">
              <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
                <polyline points="15 18 9 12 15 6" />
              </svg>
            </button>
            <div className="header-text">
              <h2 className="responses-title">Analytics Dashboard</h2>
              <p className="responses-subtitle">{form?.title || 'Formulir Ujian Semester'}</p>
            </div>
          </div>

          <button type="button" className="btn-export-csv" onClick={handleExportCsv}>
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"></path>
              <polyline points="7 10 12 15 17 10"></polyline>
              <line x1="12" y1="15" x2="12" y2="3"></line>
            </svg>
            Export CSV
          </button>
        </div>

        {/* TOP SECTION: SCORE METRICS CARD */}
        <section className="top-metrics-card">
          <div className="metrics-grid">
            <div className="metric-item">
              <span className="metric-value">{stats.totalResponses}</span>
              <span className="metric-label">Total Respons</span>
            </div>
            <div className="metric-item">
              <span className="metric-value">{stats.highestScore}</span>
              <span className="metric-label">Nilai Tertinggi</span>
            </div>
            <div className="metric-item">
              <span className="metric-value">{stats.lowestScore}</span>
              <span className="metric-label">Nilai Terendah</span>
            </div>
          </div>
        </section>

        {/* MIDDLE SECTION: RESPONDENT TABLE */}
        <section className="bottom-table-section">
          <div className="table-panel-header">
            <h3>Respondents / Individual Responses</h3>
            <button className="btn-export-small" onClick={handleExportCsv}>
              <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"></path>
                <polyline points="7 10 12 15 17 10"></polyline>
                <line x1="12" y1="15" x2="12" y2="3"></line>
              </svg>
              Export
            </button>
          </div>

          <div className="table-responsive">
            <table className="respondents-table">
              <thead>
                <tr>
                  <th>No</th>
                  <th>Responden</th>
                  <th>Email</th>
                  <th>Submitted</th>
                  <th>Score</th>
                  <th>Action</th>
                </tr>
              </thead>
              <tbody>
                {loading ? (
                  <tr>
                    <td colSpan="6" style={{ textAlign: 'center', padding: '24px' }}>Memuat data...</td>
                  </tr>
                ) : sampleRespondents.length === 0 ? (
                  <tr>
                    <td colSpan="6" style={{ textAlign: 'center', padding: '24px' }}>Belum ada respons.</td>
                  </tr>
                ) : (
                  sampleRespondents.map((resp, index) => (
                    <tr key={resp.id} onClick={() => setSelectedRespondent(resp)} style={{ cursor: 'pointer' }}>
                      <td style={{ color: '#64748b' }}>{String(index + 1).padStart(2, '0')}</td>
                      <td className="cell-flex">
                        <div className="avatar-circle" style={{ backgroundColor: resp.avatarBg }}>
                          {resp.initial}
                        </div>
                        <span style={{ fontWeight: 500, color: '#1e293b' }}>{resp.name}</span>
                      </td>
                      <td>
                        <a href={`mailto:${resp.email}`} className="text-link" onClick={(e) => e.stopPropagation()}>
                          {resp.email}
                        </a>
                      </td>
                      <td>{resp.time.split(',')[1]?.trim() || resp.time}</td>
                      <td>
                        <span className={`score-badge ${resp.score >= 70 ? 'pass' : 'fail'}`}>
                          {resp.score}
                        </span>
                      </td>
                      <td>
                        <button className="btn-view-row">View</button>
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        </section>

        {/* BOTTOM SECTION: CHARTS */}
        <section className="middle-charts-section">
          {/* Pie Chart */}
          <div className="chart-panel">
            <div className="chart-panel-header">
              <h3>Distribusi Tipe Penilaian</h3>
            </div>
            <PieChart data={stats.typePieData} size={180} />
          </div>

          {/* Vertical Bar Chart */}
          <div className="chart-panel">
            <div className="chart-panel-header">
              <h3>Score Analysis</h3>
            </div>
            <VerticalBarChart data={stats.scoreBarData} />
          </div>
        </section>



      </div>
    </MainLayout>
  )
}

export default FormResponsesPage
