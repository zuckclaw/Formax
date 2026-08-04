import { useEffect, useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import { getFormById, submitFormResponse } from '../services/formService'

const FormResponsePage = () => {
  const { formId } = useParams()
  const [form, setForm] = useState(null)
  const [answers, setAnswers] = useState({})
  const [loading, setLoading] = useState(true)
  const [submitting, setSubmitting] = useState(false)
  const [message, setMessage] = useState('')

  useEffect(() => {
    const loadForm = async () => {
      try {
        const data = await getFormById(Number(formId))
        setForm(data)

        const initialAnswers = {}
        ;(data?.questions || []).forEach((question) => {
          initialAnswers[question.id] = question.type === 'checkbox' ? [] : ''
        })
        setAnswers(initialAnswers)
      } catch (error) {
        console.error('Gagal mengambil form:', error)
      } finally {
        setLoading(false)
      }
    }

    loadForm()
  }, [formId])

  const handleChange = (questionId, value) => {
    setAnswers((prev) => ({ ...prev, [questionId]: value }))
  }

  const handleCheckboxChange = (questionId, optionValue, checked) => {
    setAnswers((prev) => {
      const current = prev[questionId] || []
      const next = checked ? [...current, optionValue] : current.filter((item) => item !== optionValue)
      return { ...prev, [questionId]: next }
    })
  }

  const handleSubmit = async (event) => {
    event.preventDefault()
    setSubmitting(true)
    setMessage('')

    try {
      const result = await submitFormResponse(Number(formId), answers)
      setMessage(`Jawaban berhasil dikirim. ID respon: ${result.id}`)
    } catch (error) {
      setMessage('Gagal mengirim jawaban.')
    } finally {
      setSubmitting(false)
    }
  }

  if (loading) {
    return <div className="page-shell"><main className="content"><p>Memuat form...</p></main></div>
  }

  if (!form) {
    return <div className="page-shell"><main className="content"><p>Form tidak ditemukan.</p></main></div>
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
            <h2>{form.title}</h2>
          </div>
          <Link to={`/forms/${form.id}/responses`} className="secondary-link">Lihat Respon</Link>
        </header>

        <section className="card form-card">
          <form onSubmit={handleSubmit} className="form-panel">
            {form.questions.map((question) => (
              <div key={question.id} className="response-question">
                <label className="question-label">
                  <span>
                    {question.label}
                    {question.required ? <strong>*</strong> : null}
                  </span>
                </label>

                {question.type === 'text' && (
                  <input
                    type="text"
                    value={answers[question.id] || ''}
                    onChange={(event) => handleChange(question.id, event.target.value)}
                    required={question.required}
                  />
                )}

                {question.type === 'email' && (
                  <input
                    type="email"
                    value={answers[question.id] || ''}
                    onChange={(event) => handleChange(question.id, event.target.value)}
                    required={question.required}
                  />
                )}

                {question.type === 'textarea' && (
                  <textarea
                    rows="4"
                    value={answers[question.id] || ''}
                    onChange={(event) => handleChange(question.id, event.target.value)}
                    required={question.required}
                  />
                )}

                {question.type === 'radio' && (
                  <div className="choice-group">
                    {question.options.map((option) => (
                      <label key={option.id || option} className="choice-item">
                        <input
                          type="radio"
                          name={`question-${question.id}`}
                          checked={answers[question.id] === (option.label || option)}
                          onChange={() => handleChange(question.id, option.label || option)}
                        />
                        <span>{option.label || option}</span>
                      </label>
                    ))}
                  </div>
                )}

                {question.type === 'checkbox' && (
                  <div className="choice-group">
                    {question.options.map((option) => (
                      <label key={option.id || option} className="choice-item">
                        <input
                          type="checkbox"
                          checked={(answers[question.id] || []).includes(option.label || option)}
                          onChange={(event) => handleCheckboxChange(question.id, option.label || option, event.target.checked)}
                        />
                        <span>{option.label || option}</span>
                      </label>
                    ))}
                  </div>
                )}

                {question.type === 'dropdown' && (
                  <select
                    value={answers[question.id] || ''}
                    onChange={(event) => handleChange(question.id, event.target.value)}
                    required={question.required}
                  >
                    <option value="">Pilih opsi</option>
                    {question.options.map((option) => (
                      <option key={option.id || option} value={option.label || option}>
                        {option.label || option}
                      </option>
                    ))}
                  </select>
                )}

                {question.type === 'file' && (
                  <input type="file" disabled />
                )}
              </div>
            ))}

            {message ? <div className="success-box">{message}</div> : null}

            <div className="form-actions">
              <button type="submit" className="primary-btn" disabled={submitting}>
                {submitting ? 'Mengirim...' : 'Kirim Jawaban'}
              </button>
              <Link to="/forms" className="secondary-link">Kembali</Link>
            </div>
          </form>
        </section>
      </main>
    </div>
  )
}

export default FormResponsePage
