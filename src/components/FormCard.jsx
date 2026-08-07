import { useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { deleteForm } from '../services/formService'

const FormCard = ({ form, mode = 'history', onDeleteSuccess }) => {
  const navigate = useNavigate()
  const [showMenu, setShowMenu] = useState(false)

  const handleDelete = async (e) => {
    e.stopPropagation()
    if (window.confirm(`Apakah Anda yakin ingin menghapus form "${form.title}"?`)) {
      await deleteForm(form.id)
      if (onDeleteSuccess) onDeleteSuccess(form.id)
    }
  }

  // Renders document preview illustration
  const renderDocumentThumbnail = () => {
    return (
      <div className="doc-thumbnail">
        <div className="doc-sheet">
          <div className="doc-header-line"></div>
          <div className="doc-body-line width-full"></div>
          <div className="doc-body-line width-medium"></div>
          <div className="doc-footer-block"></div>
        </div>
      </div>
    )
  }

  if (mode === 'template-builtin') {
    return (
      <div
        className="form-card-item builtin-card"
        onClick={() => navigate(`/builder?template=${form.id}`)}
      >
        {form.badge && (
          <div className="card-timer-badge">
            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <circle cx="12" cy="12" r="9" />
              <polyline points="12 6 12 12 16 14" />
            </svg>
            <span>{form.badge}</span>
          </div>
        )}
        <div className="card-thumb-container">
          <div className="doc-sheet preview-sheet">
            <div className="doc-header-line accent-line"></div>
            <div className="doc-body-line width-full"></div>
            <div className="doc-body-line width-short"></div>
            <div className="doc-footer-block accent-block"></div>
          </div>
        </div>
        <div className="card-info">
          <h4 className="card-title">{form.title}</h4>
          <p className="card-subtitle">{form.subtitle}</p>
        </div>
      </div>
    )
  }

  return (
    <div className="form-card-item">
      {/* Thumbnail Document Preview */}
      <div className="card-thumb-container" onClick={() => navigate(`/forms/${form.id}`)}>
        {renderDocumentThumbnail()}
      </div>

      {/* Card Info & Footer */}
      <div className="card-body-wrapper">
        <div className="card-main-meta">
          <h4 className="card-title" title={form.title}>{form.title}</h4>
          {form.updatedAt && (
            <p className="card-timestamp">{form.updatedAt.startsWith('Updated') ? form.updatedAt : `Updated ${form.updatedAt}`}</p>
          )}
        </div>

        {/* Action: Mode History has "Lihat Hasil", Mode Dashboard/Templates has 3 dots menu */}
        {mode === 'history-page' ? (
          <Link to={`/forms/${form.id}/responses`} className="btn-lihat-hasil">
            Lihat Hasil
          </Link>
        ) : (
          <div className="card-menu-container">
            <button
              className="card-menu-trigger"
              onClick={(e) => {
                e.stopPropagation()
                setShowMenu(!showMenu)
              }}
              title="Opsi"
            >
              ⋮
            </button>
            {showMenu && (
              <div className="card-dropdown-menu" onClick={(e) => e.stopPropagation()}>
                <button onClick={() => { setShowMenu(false); navigate(`/forms/${form.id}/edit`); }}>
                  Edit Form
                </button>
                <button onClick={() => { setShowMenu(false); navigate(`/forms/${form.id}/responses`); }}>
                  Lihat Hasil
                </button>
                <button className="menu-danger" onClick={handleDelete}>
                  Hapus Form
                </button>
              </div>
            )}
          </div>
        )}
      </div>
    </div>
  )
}

export default FormCard
