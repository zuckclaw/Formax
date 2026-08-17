import { useState, useEffect } from 'react'
import { useNavigate, useSearchParams } from 'react-router-dom'
import MainLayout from '../components/MainLayout'
import { createForm, getFormById, updateForm } from '../services/formService'
import WysiwygEditor from '../components/WysiwygEditor'
import { processImageFile } from '../utils/imageUtils'

const initialQuestions = [
  {
    id: 1,
    title: 'Ibu kota Indonesia adalah?',
    type: 'mc', // mc = Pilihan Ganda, sa = Isian Singkat, paragraph = Paragraf, cb = Checkbox
    required: true,
    options: ['Jakarta', 'Bandung', 'Surabaya', 'Medan'],
  },
  {
    id: 2,
    title: 'Berapa jumlah provinsi di Indonesia saat ini?',
    type: 'mc',
    required: true,
    options: ['34', '36', '37', '38'],
  },
  {
    id: 3,
    title: 'Jelaskan secara singkat mengenai letak astronomis Indonesia dan dampaknya terhadap iklim.',
    type: 'sa',
    required: false,
    options: [],
  },
  {
    id: 4,
    title: 'Menurut pendapat Anda, apa tantangan terbesar dalam pembangunan infrastruktur di daerah terpencil?',
    type: 'paragraph',
    required: false,
    options: [],
  },
]

const FormBuilderPage = () => {
  const navigate = useNavigate()
  const [searchParams] = useSearchParams()
  const formId = searchParams.get('id')
  const templateType = searchParams.get('template')

  // Navigation Tabs: 'soal' | 'setelan'
  const [activeTab, setActiveTab] = useState('soal')

  // Form State
  const [formTitle, setFormTitle] = useState('Ujian Tengah Semester')
  const [formDesc, setFormDesc] = useState('Evaluasi materi pertemuan 1-7 mata pelajaran Geografi.')
  const [questions, setQuestions] = useState(initialQuestions)
  const [activeQuestionId, setActiveQuestionId] = useState(1)
  const [imageUrlDrafts, setImageUrlDrafts] = useState({})
  const [imagePanelOpen, setImagePanelOpen] = useState({})

  // Settings State
  const [isQuiz, setIsQuiz] = useState(true)
  const [releaseGrade, setReleaseGrade] = useState('immediate') // 'immediate' | 'manual'
  const [showUnanswered, setShowUnanswered] = useState(true)
  const [showCorrectAnswers, setShowCorrectAnswers] = useState(true)
  const [showPointValues, setShowPointValues] = useState(true)
  const [defaultPoints, setDefaultPoints] = useState(0)

  // Response Settings
  const [sendResponseCopy, setSendResponseCopy] = useState('none')
  const [limitOneResponse, setLimitOneResponse] = useState(true)
  const [hideAnswers, setHideAnswers] = useState(false)
  const [allowMultipleSubmissions, setAllowMultipleSubmissions] = useState(false)
  const [makeRequiredByDefault, setMakeRequiredByDefault] = useState(false)

  // Timer Settings State & Modal
  const [showTimerModal, setShowTimerModal] = useState(false)
  const [timerEnabled, setTimerEnabled] = useState(true)
  const [timerMode, setTimerMode] = useState('Start when respondent opens the form')
  const [timerDuration, setTimerDuration] = useState('1 hari')

  useEffect(() => {
    if (formId) {
      loadForm(formId)
    } else if (templateType === 'exam') {
      setFormTitle('Exam Form')
      setFormDesc('Assessments & Quizzes')
      setTimerEnabled(true)
    } else if (templateType === 'attendance') {
      setFormTitle('Attendance Form')
      setFormDesc('Event or class tracking')
      setTimerEnabled(false)
    }
  }, [formId, templateType])

  const loadForm = async (id) => {
    const data = await getFormById(id)
    if (data) {
      setFormTitle(data.title || 'Form Tanpa Judul')
      setFormDesc(data.description || '')
      if (data.questions && data.questions.length > 0) {
        setQuestions(data.questions)
      }
    }
  }

  const handleSaveForm = async () => {
    const payload = {
      title: formTitle,
      description: formDesc,
      questions: questions.map((q) =>
        imageUrlDrafts[q.id] && !q.imageSrc
          ? { ...q, imageSrc: imageUrlDrafts[q.id].trim() }
          : q
      ),
      timerEnabled,
      timerDuration,
      isQuiz,
    }

    if (formId) {
      await updateForm(formId, payload)
    } else {
      await createForm(payload)
    }

    alert('Form berhasil disimpan!')
    navigate('/dashboard')
  }

  // Question Management
  const addQuestion = () => {
    const newId = Date.now()
    const newQ = {
      id: newId,
      title: 'Pertanyaan Tanpa Judul',
      type: 'mc',
      required: makeRequiredByDefault,
      options: ['Opsi 1'],
      imageSrc: '',
    }
    setQuestions((prev) => [...prev, newQ])
    setActiveQuestionId(newId)
  }

  const updateQuestion = (id, field, value) => {
    setQuestions((prev) =>
      prev.map((q) => (q.id === id ? { ...q, [field]: value } : q))
    )
  }

  const duplicateQuestion = (id) => {
    const target = questions.find((q) => q.id === id)
    if (target) {
      const cloned = {
        ...target,
        id: Date.now(),
        title: `${target.title} (Salinan)`,
        options: [...target.options],
      }
      setQuestions((prev) => [...prev, cloned])
      setActiveQuestionId(cloned.id)
    }
  }

  const deleteQuestion = (id) => {
    if (questions.length === 1) return alert('Form harus memiliki minimal 1 pertanyaan.')
    setQuestions((prev) => prev.filter((q) => q.id !== id))
  }

  const addOption = (qId) => {
    setQuestions((prev) =>
      prev.map((q) => {
        if (q.id !== qId) return q
        return {
          ...q,
          options: [...q.options, `Opsi ${q.options.length + 1}`],
        }
      })
    )
  }

  const updateOption = (qId, idx, value) => {
    setQuestions((prev) =>
      prev.map((q) => {
        if (q.id !== qId) return q
        const newOpts = [...q.options]
        newOpts[idx] = value
        return { ...q, options: newOpts }
      })
    )
  }

  const deleteOption = (qId, idx) => {
    setQuestions((prev) =>
      prev.map((q) => {
        if (q.id !== qId) return q
        return {
          ...q,
          options: q.options.filter((_, i) => i !== idx),
        }
      })
    )
  }

  // Image Block Helpers
  const setImageUrlDraft = (qId, value) => {
    setImageUrlDrafts((prev) => ({ ...prev, [qId]: value }))
  }

  const toggleImagePanel = (qId) => {
    setImagePanelOpen((prev) => ({ ...prev, [qId]: !prev[qId] }))
  }

  const applyImageUrl = (qId) => {
    const draft = (imageUrlDrafts[qId] || '').trim()
    if (draft) {
      updateQuestion(qId, 'imageSrc', draft)
    }
  }

  const clearImageUrlDraft = (qId) => {
    setImageUrlDrafts((prev) => {
      const next = { ...prev }
      delete next[qId]
      return next
    })
  }

  return (
    <MainLayout hideSearch={true}>
      <div className="builder-header-bar">
        <button className="back-arrow-btn" onClick={() => navigate('/dashboard')} title="Kembali ke Dashboard">
          <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
            <polyline points="15 18 9 12 15 6" />
          </svg>
        </button>

        {/* Center Tabs: Soal | Setelan */}
        <div className="builder-tabs">
          <button
            className={`tab-btn ${activeTab === 'soal' ? 'active' : ''}`}
            onClick={() => setActiveTab('soal')}
          >
            Soal
          </button>
          <button
            className={`tab-btn ${activeTab === 'setelan' ? 'active' : ''}`}
            onClick={() => setActiveTab('setelan')}
          >
            Setelan
          </button>
        </div>

        <button className="btn-simpan-draf" onClick={handleSaveForm}>
          Simpan Draf
        </button>
      </div>

      {/* ===================================================================
          TAB 1: SOAL (FORM BUILDER VIEW)
          =================================================================== */}
      {activeTab === 'soal' && (
        <div className="builder-content-container">
          <div className="builder-cards-stack">
            {/* Form Title & Description Card */}
            <div className="builder-card title-card">
              <div className="accent-top-bar"></div>
              <WysiwygEditor
                className="form-title-field"
                value={formTitle}
                onChange={setFormTitle}
                placeholder="Judul Form"
              />
              <WysiwygEditor
                className="form-desc-field"
                value={formDesc}
                onChange={setFormDesc}
                placeholder="Deskripsi Form"
              />
            </div>

            {/* Questions Stack */}
            {questions.map((q) => {
              const isActive = activeQuestionId === q.id

              if (isActive) {
                return (
                  <div key={q.id} className="builder-card question-card-active">
                    <div className="active-left-indicator"></div>

                    {/* Question Row: Title + Type Dropdown */}
                    <div className="q-edit-header">
                      <WysiwygEditor
                        className="q-title-input"
                        value={q.title}
                        onChange={(val) => updateQuestion(q.id, 'title', val)}
                        placeholder="Pertanyaan"
                      />
                      <div className="q-header-tools">
                        <button
                          type="button"
                          className={`btn-q-image ${q.imageSrc ? 'has-image' : ''}`}
                          onClick={() => toggleImagePanel(q.id)}
                          title={q.imageSrc ? 'Ganti / Hapus Gambar Soal' : 'Tambah Gambar ke Soal'}
                        >
                          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                            <rect x="3" y="3" width="18" height="18" rx="2" ry="2" />
                            <circle cx="8.5" cy="8.5" r="1.5" />
                            <polyline points="21 15 16 10 5 21" />
                          </svg>
                        </button>
                        <select
                          className="q-type-select"
                          value={q.type}
                          onChange={(e) => updateQuestion(q.id, 'type', e.target.value)}
                        >
                          <option value="mc">🔘 Pilihan Ganda</option>
                          <option value="sa">📝 Isian Singkat</option>
                          <option value="paragraph">📄 Paragraf</option>
                          <option value="cb">☑️ Kotak Centang</option>
                        </select>
                      </div>
                    </div>

                    {/* Attached Image for the Question */}
                    <div className="question-image-area">
                      {q.imageSrc && (
                        <div className="question-image-preview">
                          <img src={q.imageSrc} alt="Preview gambar soal" className="builder-image-preview" />
                        </div>
                      )}

                      {imagePanelOpen[q.id] && (
                          <div className="image-upload-zone question-image-upload">
                            <label className="image-upload-label">
                              <span>📁 Pilih File Gambar</span>
                              <input
                                type="file"
                                accept="image/*"
                                onChange={async (e) => {
                                  const file = e.target.files[0]
                                  if (!file) return
                                  try {
                                    const dataUrl = await processImageFile(file)
                                    updateQuestion(q.id, 'imageSrc', dataUrl)
                                  } catch (err) {
                                    alert(err.message)
                                  } finally {
                                    e.target.value = ''
                                  }
                                }}
                                style={{ display: 'none' }}
                              />
                            </label>
                            <span className="or-divider">atau</span>
                            <div className="image-url-row">
                              <input
                                type="text"
                                placeholder="Masukkan URL Gambar..."
                                className="image-url-input"
                                value={imageUrlDrafts[q.id] || ''}
                                onChange={(e) => setImageUrlDraft(q.id, e.target.value)}
                                onKeyDown={(e) => {
                                  if (e.key === 'Enter') {
                                    e.preventDefault()
                                    applyImageUrl(q.id)
                                  }
                                }}
                              />
                              <button
                                type="button"
                                className="btn-apply-url"
                                onClick={() => applyImageUrl(q.id)}
                              >
                                Gunakan URL
                              </button>
                            </div>
                            {q.imageSrc && (
                              <button
                                type="button"
                                className="btn-remove-image"
                                onClick={() => {
                                  updateQuestion(q.id, 'imageSrc', '')
                                  clearImageUrlDraft(q.id)
                                }}
                              >
                                Hapus Gambar
                              </button>
                            )}
                          </div>
                        )}
                    </div>

                    {/* Options area for Choice types */}
                    {['mc', 'cb'].includes(q.type) && (
                      <div className="q-options-list">
                        {q.options.map((opt, idx) => (
                          <div key={idx} className="q-option-item">
                            <div className={`opt-bullet ${q.type === 'cb' ? 'opt-cb' : 'opt-radio'}`}></div>
                            <input
                              type="text"
                              className="opt-input"
                              value={opt}
                              onChange={(e) => updateOption(q.id, idx, e.target.value)}
                            />
                            {q.options.length > 1 && (
                              <button
                                className="opt-delete-btn"
                                onClick={() => deleteOption(q.id, idx)}
                              >
                                ✕
                              </button>
                            )}
                          </div>
                        ))}
                        <div className="add-opt-row">
                          <button className="btn-add-opt" onClick={() => addOption(q.id)}>
                            Tambah opsi
                          </button>
                        </div>
                      </div>
                    )}

                    {q.type === 'sa' && (
                      <div className="preview-field-placeholder">Teks jawaban singkat...</div>
                    )}

                    {q.type === 'paragraph' && (
                      <div className="preview-field-placeholder">Teks jawaban panjang...</div>
                    )}

                    {/* Bottom Actions Bar */}
                    <div className="q-card-footer">
                      <button className="icon-action-btn" onClick={() => duplicateQuestion(q.id)} title="Duplikat">
                        📋
                      </button>
                      <button className="icon-action-btn" onClick={() => deleteQuestion(q.id)} title="Hapus">
                        🗑️
                      </button>
                      <>
                        <div className="footer-divider"></div>
                        <label className="toggle-required-label">
                          <span>Wajib diisi</span>
                          <input
                            type="checkbox"
                            className="switch-input"
                            checked={q.required}
                            onChange={(e) => updateQuestion(q.id, 'required', e.target.checked)}
                          />
                        </label>
                      </>
                    </div>
                  </div>
                )
              }

              // Unfocused / Preview Question Card
              return (
                <div
                  key={q.id}
                  className="builder-card question-card-preview"
                  onClick={() => setActiveQuestionId(q.id)}
                >
                  {q.imageSrc && (
                    <div className="preview-image-block">
                      <img src={q.imageSrc} alt={q.title || 'Gambar'} className="preview-image-el" />
                    </div>
                  )}

                  <h3 
                    className="preview-q-title"
                    dangerouslySetInnerHTML={{
                      __html: `${q.title || 'Pertanyaan Tanpa Judul'} ${q.required ? '<span class="req-star">* Wajib diisi</span>' : ''}`
                    }}
                  />

                  {['mc', 'cb'].includes(q.type) && (
                    <div className="preview-options">
                      {q.options.map((opt, i) => (
                        <div key={i} className="preview-opt-item">
                          <span className="opt-icon">{q.type === 'cb' ? '🔲' : '⚪'}</span>
                          <span>{opt}</span>
                        </div>
                      ))}
                    </div>
                  )}

                  {q.type === 'sa' && (
                    <div className="preview-text-box">Ketik jawaban Anda di sini...</div>
                  )}

                  {q.type === 'paragraph' && (
                    <div className="preview-text-box large">Jawaban teks panjang...</div>
                  )}
                </div>
              )
            })}
          </div>

          {/* Floating Toolbar on the Right */}
          <div className="floating-toolbox">
            <button className="tool-btn" onClick={addQuestion} title="Tambah Pertanyaan">
              ➕
            </button>
            <button className="tool-btn" title="Tambah Judul & Deskripsi">
              Tt
            </button>
            <button className="tool-btn" title="Tambah Video">
              🎬
            </button>
          </div>
        </div>
      )}

      {/* ===================================================================
          TAB 2: SETELAN (SETTINGS VIEW)
          =================================================================== */}
      {activeTab === 'setelan' && (
        <div className="settings-content-container">
          {/* Card 1: Jadikan ini sebagai kuis */}
          <div className="settings-card">
            <div className="settings-card-header">
              <div>
                <h3 className="setting-title">Jadikan ini sebagai kuis</h3>
                <p className="setting-subtext">Menetapkan pertanyaan dan nilai poin, serta menyediakan masukan secara otomatis</p>
              </div>
              <input
                type="checkbox"
                className="switch-input"
                checked={isQuiz}
                onChange={(e) => setIsQuiz(e.target.checked)}
              />
            </div>

            {isQuiz && (
              <div className="quiz-options-subcard">
                <div className="setting-subgroup">
                  <label className="subgroup-title">RILIS NILAI</label>
                  <label className="radio-option">
                    <input
                      type="radio"
                      name="releaseGrade"
                      checked={releaseGrade === 'immediate'}
                      onChange={() => setReleaseGrade('immediate')}
                    />
                    <span>Langsung setelah setiap pengiriman</span>
                  </label>
                  <label className="radio-option">
                    <input
                      type="radio"
                      name="releaseGrade"
                      checked={releaseGrade === 'manual'}
                      onChange={() => setReleaseGrade('manual')}
                    />
                    <div>
                      <span>Nanti, setelah peninjauan manual</span>
                      <small className="option-help">Aktifkan Respons → Kumpulkan alamat email</small>
                    </div>
                  </label>
                </div>

                <div className="setting-subgroup">
                  <label className="subgroup-title">SETELAN RESPONDEN</label>
                  <label className="toggle-row-item">
                    <span>Pertanyaan tak terjawab</span>
                    <input
                      type="checkbox"
                      className="switch-input"
                      checked={showUnanswered}
                      onChange={(e) => setShowUnanswered(e.target.checked)}
                    />
                  </label>
                  <label className="toggle-row-item">
                    <span>Jawaban yang benar</span>
                    <input
                      type="checkbox"
                      className="switch-input"
                      checked={showCorrectAnswers}
                      onChange={(e) => setShowCorrectAnswers(e.target.checked)}
                    />
                  </label>
                  <label className="toggle-row-item">
                    <span>Nilai poin</span>
                    <input
                      type="checkbox"
                      className="switch-input"
                      checked={showPointValues}
                      onChange={(e) => setShowPointValues(e.target.checked)}
                    />
                  </label>
                </div>

                <div className="setting-subgroup">
                  <label className="subgroup-title">DEFAULT KUIS GLOBAL</label>
                  <div className="default-points-row">
                    <span>Nilai poin pertanyaan default</span>
                    <div className="points-input-box">
                      <input
                        type="number"
                        value={defaultPoints}
                        onChange={(e) => setDefaultPoints(Number(e.target.value))}
                      />
                      <span>poin</span>
                    </div>
                  </div>
                </div>
              </div>
            )}
          </div>

          {/* Card 2: Jawaban */}
          <div className="settings-card">
            <div className="settings-card-header">
              <div>
                <h3 className="setting-title">Jawaban</h3>
                <p className="setting-subtext">Mengelola cara respons dikumpulkan dan dilindungi</p>
              </div>
            </div>

            <div className="settings-card-body">
              <div className="setting-row">
                <span>Mengirim salinan jawaban responden</span>
                <select
                  value={sendResponseCopy}
                  onChange={(e) => setSendResponseCopy(e.target.value)}
                  className="select-pill"
                >
                  <option value="none">Nonaktif</option>
                  <option value="always">Always</option>
                </select>
              </div>

              <div className="setting-row">
                <div>
                  <div>Batasi ke 1 jawaban</div>
                  <small className="option-help">Responden akan diwajibkan untuk login</small>
                </div>
                <input
                  type="checkbox"
                  className="switch-input"
                  checked={limitOneResponse}
                  onChange={(e) => setLimitOneResponse(e.target.checked)}
                />
              </div>

              <div className="setting-row">
                <span>Sembunyikan jawaban</span>
                <input
                  type="checkbox"
                  className="switch-input"
                  checked={hideAnswers}
                  onChange={(e) => setHideAnswers(e.target.checked)}
                />
              </div>

              <div className="setting-row">
                <span>Isi Form lebih dari 1 kali</span>
                <input
                  type="checkbox"
                  className="switch-input"
                  checked={allowMultipleSubmissions}
                  onChange={(e) => setAllowMultipleSubmissions(e.target.checked)}
                />
              </div>
            </div>
          </div>

          {/* Card 3: Default */}
          <div className="settings-card">
            <div className="settings-card-header">
              <div>
                <h3 className="setting-title">Default</h3>
                <p className="setting-subtext">Setelan diterapkan untuk semua pertanyaan</p>
              </div>
            </div>

            <div className="settings-card-body">
              <div className="setting-row">
                <span>Buat pertanyaan wajib diisi secara default</span>
                <input
                  type="checkbox"
                  className="switch-input"
                  checked={makeRequiredByDefault}
                  onChange={(e) => setMakeRequiredByDefault(e.target.checked)}
                />
              </div>

              {/* Timer Setting Row with Edit Button */}
              <div className="setting-row timer-row">
                <div className="timer-info-label">
                  <span className="font-semibold">Timer</span>
                  {timerEnabled && <span className="timer-active-badge">Aktif ({timerDuration})</span>}
                </div>
                <button
                  className="btn-edit-timer"
                  onClick={() => setShowTimerModal(true)}
                >
                  Edit
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* ===================================================================
          MODAL: FORM TIMER SETTINGS (MATCHING SCREENSHOT 1)
          =================================================================== */}
      {showTimerModal && (
        <div className="modal-backdrop">
          <div className="timer-modal-card">
            <div className="timer-modal-header">
              <div className="timer-icon-circle">⏱️</div>
              <div>
                <h3 className="timer-modal-title">Form Timer</h3>
                <p className="timer-modal-sub">Manage constraints and timing for this form</p>
              </div>
            </div>

            <div className="timer-modal-body">
              {/* Enable Timer Toggle */}
              <div className="timer-toggle-row">
                <div>
                  <div className="timer-toggle-title">Enable Timer</div>
                  <div className="timer-toggle-sub">Set a time limit for form completion</div>
                </div>
                <input
                  type="checkbox"
                  className="switch-input"
                  checked={timerEnabled}
                  onChange={(e) => setTimerEnabled(e.target.checked)}
                />
              </div>

              {timerEnabled && (
                <>
                  {/* Select Timer Mode */}
                  <div className="timer-field-group">
                    <label className="timer-label">Select Timer Mode</label>
                    <select
                      className="timer-select-input"
                      value={timerMode}
                      onChange={(e) => setTimerMode(e.target.value)}
                    >
                      <option value="Start when respondent opens the form">Start when respondent opens the form</option>
                      <option value="Fixed start and end date">Fixed start and end date</option>
                    </select>
                  </div>

                  {/* Duration Input */}
                  <div className="timer-field-group">
                    <label className="timer-label">Duration</label>
                    <input
                      type="text"
                      className="timer-text-input"
                      value={timerDuration}
                      onChange={(e) => setTimerDuration(e.target.value)}
                      placeholder="Contoh: 1 hari atau 60 menit"
                    />
                  </div>

                  {/* Info Callout */}
                  <div className="timer-info-callout">
                    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#2563eb" strokeWidth="2">
                      <circle cx="12" cy="12" r="10" />
                      <line x1="12" y1="16" x2="12" y2="12" />
                      <line x1="12" y1="8" x2="12.01" y2="8" />
                    </svg>
                    <span>The form will auto-submit and lock once the timer runs out. Respondents will see a countdown display at the top of the page.</span>
                  </div>
                </>
              )}
            </div>

            {/* Modal Footer Actions */}
            <div className="timer-modal-footer">
              <button
                className="btn-discard"
                onClick={() => setShowTimerModal(false)}
              >
                Discard Changes
              </button>
              <button
                className="btn-save-settings"
                onClick={() => setShowTimerModal(false)}
              >
                Save Settings
              </button>
            </div>
          </div>
        </div>
      )}

    </MainLayout>
  )
}

export default FormBuilderPage
