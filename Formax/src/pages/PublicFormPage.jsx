import { useEffect, useState } from 'react'
import { useParams, useNavigate, Link } from 'react-router-dom'
import { getFormById, submitFormResponse } from '../services/formService'

const PublicFormPage = () => {
  const { formId } = useParams()
  const navigate = useNavigate()
  const [form, setForm] = useState(null)
  const [answers, setAnswers] = useState({})
  const [loading, setLoading] = useState(true)
  const [submitting, setSubmitting] = useState(false)
  const [submitted, setSubmitted] = useState(false)

  // Respondent Info
  const [respondentName, setRespondentName] = useState('')
  const [respondentEmail, setRespondentEmail] = useState('')

  // Live Timer Countdown State
  const [timeLeftSeconds, setTimeLeftSeconds] = useState(null)
  const [isTimerRunning, setIsTimerRunning] = useState(false)

  // Live Form Update Notification State
  const [showUpdateNotice, setShowUpdateNotice] = useState(false)

  useEffect(() => {
    loadPublicForm()

    // Event listener for live updates when form owner modifies form in another tab
    const handleStorageChange = (e) => {
      if (e.key === 'formax_user_forms' || e.key === 'formax_form_updated') {
        setShowUpdateNotice(true)
      }
    }
    window.addEventListener('storage', handleStorageChange)
    return () => window.removeEventListener('storage', handleStorageChange)
  }, [formId])

  const loadPublicForm = async () => {
    try {
      const data = await getFormById(formId)
      if (data) {
        setForm(data)

        // Initialize answers state
        const initialAnswers = {}
        ;(data.questions || []).forEach((q) => {
          initialAnswers[q.id] = q.type === 'cb' || q.type === 'checkbox' ? [] : ''
        })
        setAnswers(initialAnswers)

        // Initialize Timer if enabled
        if (data.timerEnabled) {
          // Parse duration string e.g. "60 menit", "1 hari", "2 jam" or default 30 mins
          let seconds = 30 * 60
          if (data.timerDuration) {
            const dur = data.timerDuration.toLowerCase()
            if (dur.includes('hari')) {
              const num = parseInt(dur) || 1
              seconds = num * 24 * 60 * 60
            } else if (dur.includes('jam')) {
              const num = parseInt(dur) || 1
              seconds = num * 60 * 60
            } else if (dur.includes('menit')) {
              const num = parseInt(dur) || 30
              seconds = num * 60
            }
          }
          setTimeLeftSeconds(seconds)
          setIsTimerRunning(true)
        }
      }
    } catch (err) {
      console.error('Gagal memuat form publik:', err)
    } finally {
      setLoading(false)
    }
  }

  // Timer Interval Effect
  useEffect(() => {
    if (!isTimerRunning || timeLeftSeconds === null || timeLeftSeconds <= 0) return

    const timer = setInterval(() => {
      setTimeLeftSeconds((prev) => {
        if (prev <= 1) {
          clearInterval(timer)
          handleAutoSubmit()
          return 0
        }
        return prev - 1
      })
    }, 1000)

    return () => clearInterval(timer)
  }, [isTimerRunning, timeLeftSeconds])

  const handleAutoSubmit = () => {
    alert('⏱️ Waktu pengerjaan form telah habis! Jawaban Anda otomatis terkirim.')
    executeSubmit()
  }

  const handleTextChange = (qId, val) => {
    setAnswers((prev) => ({ ...prev, [qId]: val }))
  }

  const handleCheckboxChange = (qId, optVal, checked) => {
    setAnswers((prev) => {
      const current = prev[qId] || []
      const next = checked ? [...current, optVal] : current.filter((v) => v !== optVal)
      return { ...prev, [qId]: next }
    })
  }

  const executeSubmit = async () => {
    setSubmitting(true)
    try {
      // Prepare payload with respondent name & answers
      const payload = {
        respondent_name: respondentName || 'Responden',
        respondent_email: respondentEmail || 'responden@email.com',
        submitted_at: 'Hari ini, ' + new Date().toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit' }) + ' WIB',
        answers,
      }
      await submitFormResponse(formId, payload)
      setSubmitted(true)
    } catch (err) {
      console.error('Gagal mengirim jawaban:', err)
      alert('Gagal mengirim jawaban. Silakan coba lagi.')
    } finally {
      setSubmitting(false)
    }
  }

  const handleSubmit = (e) => {
    e.preventDefault()
    executeSubmit()
  }

  const formatTimer = (totalSec) => {
    if (totalSec === null) return ''
    const hrs = Math.floor(totalSec / 3600)
    const mins = Math.floor((totalSec % 3600) / 60)
    const secs = totalSec % 60
    if (hrs > 0) {
      return `${String(hrs).padStart(2, '0')}:${String(mins).padStart(2, '0')}:${String(secs).padStart(2, '0')}`
    }
    return `${String(mins).padStart(2, '0')}:${String(secs).padStart(2, '0')}`
  }

  if (loading) {
    return (
      <div className="public-page-shell">
        <div className="public-form-container">
          <p className="loading-text">Memuat form...</p>
        </div>
      </div>
    )
  }

  if (!form) {
    return (
      <div className="public-page-shell">
        <div className="public-form-container">
          <div className="form-card-box">
            <h2>Form Tidak Ditemukan</h2>
            <p>Form yang Anda cari tidak tersedia atau telah dihapus.</p>
            <Link to="/dashboard" className="primary-btn button-link mt-4">Kembali ke Dashboard</Link>
          </div>
        </div>
      </div>
    )
  }

  // Submitted Thank You View
  if (submitted) {
    return (
      <div className="public-page-shell">
        <div className="public-form-container">
          <div className="form-card-box thank-you-box">
            <div className="check-icon-circle">✓</div>
            <h2>Jawaban Anda telah terrekam</h2>
            <p>Terima kasih telah meluangkan waktu untuk mengisi form <strong>"{form.title}"</strong>.</p>

            <div className="thank-you-actions">
              <button
                className="secondary-btn"
                onClick={() => {
                  setSubmitted(false)
                  setAnswers({})
                }}
              >
                Kirim Jawaban Lain
              </button>
              <Link to={`/forms/${formId}/responses`} className="primary-btn button-link">
                Lihat Hasil Respons
              </Link>
            </div>
          </div>
        </div>
      </div>
    )
  }

  return (
    <div className="public-page-shell">
      {/* Live Form Update Banner Notification */}
      {showUpdateNotice && (
        <div className="update-notice-banner">
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z" />
            <line x1="12" y1="9" x2="12" y2="13" />
            <line x1="12" y1="17" x2="12.01" y2="17" />
          </svg>
          <span>Ada perubahan pada form ini oleh pembuat. Halaman akan diperbarui otomatis...</span>
          <button
            className="btn-notice-refresh"
            onClick={() => {
              setShowUpdateNotice(false)
              loadPublicForm()
            }}
          >
            Muat Ulang Form
          </button>
        </div>
      )}

      {/* Countdown Timer Sticky Top Bar (If Enabled) */}
      {form.timerEnabled && timeLeftSeconds !== null && (
        <div className="public-timer-bar">
          <div className="timer-bar-content">
            <div className="timer-label-box">
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <circle cx="12" cy="12" r="10" />
                <polyline points="12 6 12 12 16 14" />
              </svg>
              <span>Sisa Waktu Pengerjaan:</span>
            </div>
            <div className={`timer-clock-badge ${timeLeftSeconds < 180 ? 'urgent' : ''}`}>
              {formatTimer(timeLeftSeconds)}
            </div>
          </div>
        </div>
      )}

      <div className="public-form-container">
        <form onSubmit={handleSubmit}>
          {/* Header Card */}
          <div className="form-card-box title-card-box">
            <div className="accent-top-strip"></div>
            <h1 className="public-form-title">{form.title}</h1>
            {form.description && (
              <p className="public-form-desc" dangerouslySetInnerHTML={{ __html: form.description }} />
            )}

            {/* Respondent Identity Fields */}
            <div className="respondent-identity-fields">
              <label>
                <span>Nama Lengkap Responden *</span>
                <input
                  type="text"
                  value={respondentName}
                  onChange={(e) => setRespondentName(e.target.value)}
                  placeholder="Masukkan nama lengkap Anda"
                  required
                />
              </label>
              <label>
                <span>Alamat Email Responden *</span>
                <input
                  type="email"
                  value={respondentEmail}
                  onChange={(e) => setRespondentEmail(e.target.value)}
                  placeholder="contoh: responden@email.com"
                  required
                />
              </label>
            </div>
          </div>

          {/* Question Cards */}
          {(form.questions || []).map((q, idx) => (
            <div key={q.id || idx} className="form-card-box question-card-box">
              <h3 className="public-q-title">
                {idx + 1}. <span dangerouslySetInnerHTML={{ __html: q.title || q.label }} />
                {q.required && <span className="req-star">*</span>}
              </h3>

              {/* Multiple Choice / Radio */}
              {(q.type === 'mc' || q.type === 'radio') && (
                <div className="public-options-list">
                  {(q.options || []).map((opt, oIdx) => {
                    const optLabel = typeof opt === 'string' ? opt : opt.label
                    return (
                      <label key={oIdx} className="public-opt-item">
                        <input
                          type="radio"
                          name={`q_${q.id}`}
                          checked={answers[q.id] === optLabel}
                          onChange={() => handleTextChange(q.id, optLabel)}
                          required={q.required}
                        />
                        <span>{optLabel}</span>
                      </label>
                    )
                  })}
                </div>
              )}

              {/* Checkbox */}
              {(q.type === 'cb' || q.type === 'checkbox') && (
                <div className="public-options-list">
                  {(q.options || []).map((opt, oIdx) => {
                    const optLabel = typeof opt === 'string' ? opt : opt.label
                    const currentArr = answers[q.id] || []
                    return (
                      <label key={oIdx} className="public-opt-item">
                        <input
                          type="checkbox"
                          checked={currentArr.includes(optLabel)}
                          onChange={(e) => handleCheckboxChange(q.id, optLabel, e.target.checked)}
                        />
                        <span>{optLabel}</span>
                      </label>
                    )
                  })}
                </div>
              )}

              {/* Dropdown */}
              {q.type === 'dropdown' && (
                <select
                  className="public-select-input"
                  value={answers[q.id] || ''}
                  onChange={(e) => handleTextChange(q.id, e.target.value)}
                  required={q.required}
                >
                  <option value="">-- Pilih salah satu --</option>
                  {(q.options || []).map((opt, oIdx) => {
                    const optLabel = typeof opt === 'string' ? opt : opt.label
                    return (
                      <option key={oIdx} value={optLabel}>
                        {optLabel}
                      </option>
                    )
                  })}
                </select>
              )}

              {/* Short Answer / Text */}
              {(q.type === 'sa' || q.type === 'text' || q.type === 'email') && (
                <input
                  type={q.type === 'email' ? 'email' : 'text'}
                  className="public-text-input"
                  value={answers[q.id] || ''}
                  onChange={(e) => handleTextChange(q.id, e.target.value)}
                  placeholder="Ketik jawaban Anda di sini..."
                  required={q.required}
                />
              )}

              {/* Paragraph / Textarea */}
              {(q.type === 'paragraph' || q.type === 'textarea') && (
                <textarea
                  className="public-textarea-input"
                  rows="4"
                  value={answers[q.id] || ''}
                  onChange={(e) => handleTextChange(q.id, e.target.value)}
                  placeholder="Ketik jawaban lengkap Anda di sini..."
                  required={q.required}
                />
              )}
            </div>
          ))}

          {/* Submit Button Bar */}
          <div className="public-submit-bar">
            <button type="submit" className="primary-btn btn-submit-form" disabled={submitting}>
              {submitting ? 'Mengirim Jawaban...' : 'Kirim Jawaban'}
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}

export default PublicFormPage
