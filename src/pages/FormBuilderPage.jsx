import { useState } from 'react'

const sampleQuestions = [
  { id: 1, label: 'Nama lengkap', type: 'text', required: true, options: [] },
  { id: 2, label: 'Alamat email', type: 'email', required: true, options: [] },
  { id: 3, label: 'Apakah Anda setuju?', type: 'radio', required: false, options: ['Ya', 'Tidak', 'Bisa dipertimbangkan'] },
  { id: 4, label: 'Pilih minat Anda', type: 'checkbox', required: true, options: ['Desain', 'Marketing', 'Teknologi'] },
]

const choiceTypes = ['radio', 'checkbox', 'dropdown']

const FormBuilderPage = () => {
  const [formTitle, setFormTitle] = useState('Survey Kepuasan Pelanggan')
  const [questions, setQuestions] = useState(sampleQuestions)
  const [status, setStatus] = useState('Draft')

  const addQuestion = () => {
    const newQuestion = {
      id: Date.now(),
      label: `Pertanyaan baru ${questions.length + 1}`,
      type: 'text',
      required: false,
      options: [],
    }

    setQuestions((prev) => [...prev, newQuestion])
  }

  const updateQuestion = (id, field, value) => {
    setQuestions((prev) =>
      prev.map((question) =>
        question.id === id
          ? {
              ...question,
              [field]: value,
              ...(field === 'type' && !choiceTypes.includes(value) ? { options: [] } : {}),
            }
          : question,
      ),
    )
  }

  const removeQuestion = (id) => {
    setQuestions((prev) => prev.filter((question) => question.id !== id))
  }

  const addOption = (questionId) => {
    setQuestions((prev) =>
      prev.map((question) => {
        if (question.id !== questionId) return question

        const nextOrder = question.options.length + 1
        return {
          ...question,
          options: [...question.options, { id: Date.now(), label: `Opsi ${nextOrder}` }],
        }
      }),
    )
  }

  const updateOption = (questionId, optionId, value) => {
    setQuestions((prev) =>
      prev.map((question) => {
        if (question.id !== questionId) return question

        return {
          ...question,
          options: question.options.map((option) =>
            option.id === optionId ? { ...option, label: value } : option,
          ),
        }
      }),
    )
  }

  const removeOption = (questionId, optionId) => {
    setQuestions((prev) =>
      prev.map((question) => {
        if (question.id !== questionId) return question

        return {
          ...question,
          options: question.options.filter((option) => option.id !== optionId),
        }
      }),
    )
  }

  return (
    <div className="builder-page">
      <aside className="builder-sidebar">
        <h3>Form Builder</h3>
        <button type="button" className="primary-btn" onClick={addQuestion}>
          Tambah Pertanyaan
        </button>
        <ul>
          <li>Text</li>
          <li>Email</li>
          <li>Radio</li>
          <li>Checkbox</li>
          <li>Dropdown</li>
          <li>Upload File</li>
        </ul>
      </aside>

      <main className="builder-main">
        <div className="builder-topbar">
          <div>
            <p className="mini-label">Form</p>
            <input
              className="form-title-input"
              value={formTitle}
              onChange={(event) => setFormTitle(event.target.value)}
              aria-label="Judul form"
            />
          </div>
          <button type="button" className="secondary-btn" onClick={() => setStatus('Published')}>
            {status === 'Published' ? 'Published' : 'Publish'}
          </button>
        </div>

        <div className="builder-summary">
          <span>{questions.length} pertanyaan</span>
          <span className={`status ${status.toLowerCase()}`}>{status}</span>
        </div>

        <div className="question-list">
          {questions.map((question, index) => (
            <div key={question.id} className="question-card">
              <div className="question-header">
                <span className="question-type">{question.type}</span>
                <span className="question-required">{question.required ? 'Required' : 'Optional'}</span>
              </div>

              <div className="field-row">
                <label>
                  <span>Pertanyaan {index + 1}</span>
                  <input
                    type="text"
                    value={question.label}
                    onChange={(event) => updateQuestion(question.id, 'label', event.target.value)}
                  />
                </label>

                <label>
                  <span>Tipe</span>
                  <select
                    value={question.type}
                    onChange={(event) => updateQuestion(question.id, 'type', event.target.value)}
                  >
                    <option value="text">Text</option>
                    <option value="email">Email</option>
                    <option value="textarea">Textarea</option>
                    <option value="radio">Radio</option>
                    <option value="checkbox">Checkbox</option>
                    <option value="dropdown">Dropdown</option>
                    <option value="file">Upload File</option>
                  </select>
                </label>
              </div>

              <label className="toggle-row">
                <input
                  type="checkbox"
                  checked={question.required}
                  onChange={(event) => updateQuestion(question.id, 'required', event.target.checked)}
                />
                <span>Wajib diisi</span>
              </label>

              {choiceTypes.includes(question.type) && (
                <div className="options-panel">
                  <div className="option-list">
                    {(question.options || []).map((option) => (
                      <div key={option.id} className="option-item">
                        <input
                          type="text"
                          value={option.label}
                          onChange={(event) => updateOption(question.id, option.id, event.target.value)}
                        />
                        <button type="button" className="danger-btn" onClick={() => removeOption(question.id, option.id)}>
                          Hapus
                        </button>
                      </div>
                    ))}
                  </div>

                  <button type="button" className="link-btn" onClick={() => addOption(question.id)}>
                    + Tambah Opsi
                  </button>
                </div>
              )}

              <div className="question-actions">
                <button type="button" className="danger-btn" onClick={() => removeQuestion(question.id)}>
                  Hapus
                </button>
              </div>
            </div>
          ))}
        </div>
      </main>
    </div>
  )
}

export default FormBuilderPage
