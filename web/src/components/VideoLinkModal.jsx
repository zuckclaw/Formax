import { useState, useEffect, useMemo, useRef } from 'react'
import { parseVideoUrl } from '../utils/videoEmbed'
import './VideoLinkModal.css'

export default function VideoLinkModal({ isOpen, onClose, onInsert, initialUrl = '' }) {
  const [url, setUrl] = useState(initialUrl)
  const inputRef = useRef(null)

  useEffect(() => {
    if (isOpen) {
      setUrl(initialUrl)
      setTimeout(() => inputRef.current?.focus(), 60)
    }
  }, [isOpen, initialUrl])

  useEffect(() => {
    if (!isOpen) return
    const onKey = (e) => {
      if (e.key === 'Escape') onClose()
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [isOpen, onClose])

  const parsed = useMemo(() => {
    if (!url.trim()) return null
    return parseVideoUrl(url.trim())
  }, [url])

  const isValid = !!parsed
  const trimmed = url.trim()

  const handleInsert = () => {
    if (!isValid) return
    onInsert(parsed.original)
    onClose()
  }

  const handlePaste = async () => {
    try {
      const text = await navigator.clipboard.readText()
      if (text) setUrl(text.trim())
    } catch {
      // fallback: focus input
      inputRef.current?.focus()
    }
  }

  if (!isOpen) return null

  return (
    <div className="vl-overlay" onClick={onClose}>
      <div className="vl-card" onClick={(e) => e.stopPropagation()} role="dialog" aria-modal="true">
        <div className="vl-header">
          <h3 className="vl-title">Sisipkan Video</h3>
          <button className="vl-close" onClick={onClose} aria-label="Tutup">
            <svg width="16" height="16" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.2}><line x1="18" y1="6" x2="6" y2="18" /><line x1="6" y1="6" x2="18" y2="18" /></svg>
          </button>
        </div>

        <div className="vl-body">
          <label className="vl-label">Link Video</label>
          <div className={`vl-input-row ${trimmed && !isValid ? 'is-error' : isValid ? 'is-valid' : ''}`}>
            <input
              ref={inputRef}
              className="vl-input"
              value={url}
              onChange={(e) => setUrl(e.target.value)}
              placeholder="https://..."
              spellCheck={false}
              onKeyDown={(e) => { if (e.key === 'Enter') { e.preventDefault(); handleInsert() } }}
            />
            <button className="vl-paste" onClick={handlePaste} type="button">Tempel</button>
          </div>

          {trimmed && !isValid ? (
            <p className="vl-error">Link tidak dikenali. Coba tempel link YouTube, Vimeo, Drive, atau MP4.</p>
          ) : null}

          <div className="vl-example">
            <p className="vl-example-title">Contoh:</p>
            <code className="vl-example-code">https://www.youtube.com/watch?v=dQw4w9WgXcQ</code>
          </div>
        </div>

        <div className="vl-footer">
          <button className="vl-btn secondary" onClick={onClose}>Batal</button>
          <button className="vl-btn primary" onClick={handleInsert} disabled={!isValid}>Sisipkan</button>
        </div>
      </div>
    </div>
  )
}
