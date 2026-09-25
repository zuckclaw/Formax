import { useState, useEffect, useMemo, useRef, useCallback } from 'react'
import { createPortal } from 'react-dom'
import katex from 'katex'
import './MathPicker.css'

const PRESETS = [
  {
    category: 'Umum',
    items: [
      { label: 'Pecahan', latex: '\\frac{a}{b}', display: 'a/b' },
      { label: 'Pecahan kompleks', latex: '\\frac{\\frac{a}{b}}{c}', display: '(a/b)/c' },
      { label: 'Akar kuadrat', latex: '\\sqrt{x}', display: '√x' },
      { label: 'Akar pangkat-n', latex: '\\sqrt[n]{x}', display: 'ⁿ√x' },
      { label: 'Pangkat', latex: 'x^{n}', display: 'xⁿ' },
      { label: 'Subscript', latex: 'x_{i}', display: 'xᵢ' },
      { label: 'Pangkat+sub', latex: 'x_{i}^{n}', display: 'xᵢⁿ' },
      { label: 'Plus-minus', latex: 'x \\pm y', display: 'x ± y' },
      { label: 'Kali silang', latex: 'x \\times y', display: 'x × y' },
      { label: 'Bagi (÷)', latex: 'x \\div y', display: 'x ÷ y' },
      { label: 'Titik tengah', latex: 'x \\cdot y', display: 'x · y' },
    ],
  },
  {
    category: 'Operasi Besar',
    items: [
      { label: 'Jumlah (∑)', latex: '\\sum_{i=1}^{n} x_i', display: '∑' },
      { label: 'Produk (∏)', latex: '\\prod_{i=1}^{n} x_i', display: '∏' },
      { label: 'Integral', latex: '\\int_{a}^{b} f(x)\\,dx', display: '∫' },
      { label: 'Integral lipat', latex: '\\iint_{D} f(x,y)\\,dx\\,dy', display: '∬' },
      { label: 'Limit', latex: '\\lim_{x \\to \\infty} f(x)', display: 'lim' },
      { label: 'Turunan', latex: '\\frac{dy}{dx}', display: 'dy/dx' },
      { label: 'Integral tentu besar', latex: '\\int\\limits_{0}^{\\infty} e^{-x^2} dx', display: '∫₀^∞' },
      { label: 'Union', latex: 'A \\cup B', display: '∪' },
      { label: 'Intersection', latex: 'A \\cap B', display: '∩' },
    ],
  },
  {
    category: 'Relasi & Logika',
    items: [
      { label: 'Sama dengan', latex: 'a = b', display: '=' },
      { label: 'Tidak sama', latex: 'a \\neq b', display: '≠' },
      { label: 'Kurang-lebih', latex: 'a \\approx b', display: '≈' },
      { label: 'Identik', latex: 'a \\equiv b', display: '≡' },
      { label: 'Sebanding', latex: 'a \\propto b', display: '∝' },
      { label: 'Lebih kecil', latex: 'a < b', display: '<' },
      { label: 'Lebih besar', latex: 'a > b', display: '>' },
      { label: '≤', latex: 'a \\leq b', display: '≤' },
      { label: '≥', latex: 'a \\geq b', display: '≥' },
      { label: 'Implikasi', latex: 'p \\Rightarrow q', display: '⇒' },
      { label: 'Ekuivalen', latex: 'p \\Leftrightarrow q', display: '⇔' },
      { label: 'Elemen', latex: 'x \\in A', display: '∈' },
      { label: 'Bukan elemen', latex: 'x \\notin A', display: '∉' },
      { label: 'Subset', latex: 'A \\subset B', display: '⊂' },
      { label: 'For all', latex: '\\forall x', display: '∀' },
      { label: 'Exists', latex: '\\exists x', display: '∃' },
    ],
  },
  {
    category: 'Fungsi & Trigonometri',
    items: [
      { label: 'Sin', latex: '\\sin x', display: 'sin' },
      { label: 'Cos', latex: '\\cos x', display: 'cos' },
      { label: 'Tan', latex: '\\tan x', display: 'tan' },
      { label: 'Log', latex: '\\log_{a} b', display: 'log' },
      { label: 'Ln', latex: '\\ln x', display: 'ln' },
      { label: 'Exp', latex: 'e^{x}', display: 'eˣ' },
      { label: 'Min', latex: '\\min(a,b)', display: 'min' },
      { label: 'Max', latex: '\\max(a,b)', display: 'max' },
    ],
  },
  {
    category: 'Yunani',
    items: [
      { label: 'Alpha', latex: '\\alpha', display: 'α' },
      { label: 'Beta', latex: '\\beta', display: 'β' },
      { label: 'Gamma', latex: '\\gamma', display: 'γ' },
      { label: 'Delta', latex: '\\delta', display: 'δ' },
      { label: 'Epsilon', latex: '\\epsilon', display: 'ε' },
      { label: 'Theta', latex: '\\theta', display: 'θ' },
      { label: 'Lambda', latex: '\\lambda', display: 'λ' },
      { label: 'Mu', latex: '\\mu', display: 'μ' },
      { label: 'Pi', latex: '\\pi', display: 'π' },
      { label: 'Sigma kecil', latex: '\\sigma', display: 'σ' },
      { label: 'Sigma besar', latex: '\\Sigma', display: 'Σ' },
      { label: 'Omega', latex: '\\omega', display: 'ω' },
      { label: 'Omega besar', latex: '\\Omega', display: 'Ω' },
      { label: 'Phi', latex: '\\phi', display: 'φ' },
      { label: 'Psi', latex: '\\psi', display: 'ψ' },
    ],
  },
  {
    category: 'Matriks & Vektor',
    items: [
      { label: 'Matriks 2×2', latex: '\\begin{pmatrix} a & b \\\\ c & d \\end{pmatrix}', display: '[2×2]' },
      { label: 'Determinan', latex: '\\begin{vmatrix} a & b \\\\ c & d \\end{vmatrix}', display: '|2×2|' },
      { label: 'Vektor', latex: '\\vec{a}', display: 'a⃗' },
      { label: 'Vektor tebal', latex: '\\mathbf{a}', display: '𝐚' },
      { label: 'Norma', latex: '\\| \\vec{a} \\|', display: '‖a‖' },
      { label: 'Transpos', latex: 'A^{T}', display: 'Aᵀ' },
      { label: 'Sistem persamaan', latex: '\\begin{cases} x + y = 1 \\\\ x - y = 2 \\end{cases}', display: '{..' },
      { label: 'Barisan', latex: 'a_n = a_{n-1} + d', display: 'aₙ' },
    ],
  },
  {
    category: 'Lainnya',
    items: [
      { label: 'Tak hingga', latex: '\\infty', display: '∞' },
      { label: 'Derajat', latex: '90^{\\circ}', display: '°' },
      { label: 'Persen', latex: '100\\%', display: '%' },
      { label: 'Akar + pecahan', latex: '\\sqrt{\\frac{a}{b}}', display: '√(a/b)' },
      { label: 'Kombinasi', latex: '\\binom{n}{k}', display: '(n k)' },
      { label: 'Floor', latex: '\\left\\lfloor x \\right\\rfloor', display: '⌊x⌋' },
      { label: 'Ceil', latex: '\\left\\lceil x \\right\\rceil', display: '⌈x⌉' },
      { label: 'Panah kanan', latex: '\\rightarrow', display: '→' },
      { label: 'Panah dua arah', latex: '\\leftrightarrow', display: '↔' },
    ],
  },
]

function PreviewBox({ latex, displayMode }) {
  const { html, error } = useMemo(() => {
    if (!latex.trim()) return { html: '', error: null }
    try {
      const rendered = katex.renderToString(latex, {
        throwOnError: false,
        displayMode,
        strict: false,
      })
      const hasError = rendered.includes('katex-error') || rendered.includes('ParseError')
      if (hasError) return { html: rendered, error: 'Rumus tidak valid' }
      return { html: rendered, error: null }
    } catch (e) {
      return { html: '', error: e.message }
    }
  }, [latex, displayMode])

  if (!latex.trim()) {
    return <div className="mp-preview-empty">Pratinjau akan muncul di sini</div>
  }
  return (
    <>
      <div className={`mp-preview-render ${displayMode ? 'display' : 'inline'}`} dangerouslySetInnerHTML={{ __html: html }} />
      {error && <div className="mp-preview-error">{error}</div>}
    </>
  )
}

export default function MathPicker({ isOpen, onClose, onInsert, anchorRect }) {
  const [activeTab, setActiveTab] = useState('presets')
  const [customLatex, setCustomLatex] = useState('\\frac{a}{b}')
  const [isDisplay, setIsDisplay] = useState(false)
  const [search, setSearch] = useState('')
  const [inlineEdit, setInlineEdit] = useState(null) // { label, latex, display }
  const [inlineDisplay, setInlineDisplay] = useState(false)
  const modalRef = useRef(null)
  const headerRef = useRef(null)

  // ── Draggable state ──────────────────────────────────────────────
  const [pos, setPos] = useState(null) // { left, top } or null = use anchor/default centering
  const dragState = useRef({ dragging: false, offsetX: 0, offsetY: 0 })

  const isMobile = typeof window !== 'undefined' && window.innerWidth <= 768
  const isPopover = !isMobile && !!anchorRect

  // Close on Esc
  useEffect(() => {
    if (!isOpen) return
    const onKey = (e) => {
      if (e.key === 'Escape') {
        if (inlineEdit) setInlineEdit(null)
        else onClose()
      }
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [isOpen, onClose, inlineEdit])

  // Reset when opened
  useEffect(() => {
    if (isOpen) {
      // eslint-disable-next-line react-hooks/set-state-in-effect
      setActiveTab('presets')
      setSearch('')
      setInlineEdit(null)
      setInlineDisplay(false)
      // init position from anchorRect
      if (anchorRect && !isMobile) {
        const gap = 8
        const width = Math.min(600, window.innerWidth - 24)
        let top = anchorRect.bottom + gap
        let left = anchorRect.left
        if (left + width > window.innerWidth - 12) left = window.innerWidth - width - 12
        if (left < 12) left = 12
        const estH = Math.min(560, window.innerHeight - 24)
        if (top + estH > window.innerHeight) top = anchorRect.top - estH - gap
        if (top < 12) top = 12
        setPos({ left, top })
      } else {
        setPos(null)
      }
    }
  }, [isOpen, anchorRect, isMobile])

  // Prevent background scroll when modal open (only modal, not popover)
  useEffect(() => {
    if (!isOpen || isPopover) return
    const prev = document.body.style.overflow
    document.body.style.overflow = 'hidden'
    return () => { document.body.style.overflow = prev }
  }, [isOpen, isPopover])

  const filteredPresets = useMemo(() => {
    if (!search.trim()) return PRESETS
    const q = search.toLowerCase()
    return PRESETS.map((cat) => ({
      ...cat,
      items: cat.items.filter(
        (it) => it.label.toLowerCase().includes(q) || it.latex.toLowerCase().includes(q)
      ),
    })).filter((cat) => cat.items.length > 0)
  }, [search])

  const handlePresetClick = (latex) => {
    onInsert(latex, false)
  }

  const handleEditClick = (item) => {
    setInlineEdit({ label: item.label, latex: item.latex })
    setInlineDisplay(false)
  }

  const handleInlineInsert = () => {
    if (!inlineEdit?.latex.trim()) return
    const test = katex.renderToString(inlineEdit.latex, { throwOnError: false, displayMode: inlineDisplay })
    if (test.includes('katex-error')) return
    onInsert(inlineEdit.latex, inlineDisplay)
    setInlineEdit(null)
  }

  const handleCustomInsert = () => {
    if (!customLatex.trim()) return
    try {
      katex.renderToString(customLatex, { throwOnError: true, displayMode: isDisplay, strict: false })
    } catch {
      const test = katex.renderToString(customLatex, { throwOnError: false, displayMode: isDisplay })
      if (test.includes('katex-error')) return
    }
    onInsert(customLatex, isDisplay)
  }

  const switchToCustomWithLatex = (latex) => {
    setCustomLatex(latex)
    setActiveTab('custom')
    setInlineEdit(null)
  }

  // ── Drag handlers ────────────────────────────────────────────────
  const onHeaderPointerDown = useCallback((e) => {
    if (isMobile) return
    e.stopPropagation()
    if (e.nativeEvent?.stopImmediatePropagation) e.nativeEvent.stopImmediatePropagation()
    const card = modalRef.current
    if (!card) return
    const rect = card.getBoundingClientRect()
    const clientX = e.touches ? e.touches[0].clientX : e.clientX
    const clientY = e.touches ? e.touches[0].clientY : e.clientY
    dragState.current = {
      dragging: true,
      offsetX: clientX - rect.left,
      offsetY: clientY - rect.top,
    }
    card.classList.add('mp-dragging')
    e.preventDefault()
  }, [isMobile])

  useEffect(() => {
    const onMove = (e) => {
      if (!dragState.current.dragging) return
      const clientX = e.touches ? e.touches[0].clientX : e.clientX
      const clientY = e.touches ? e.touches[0].clientY : e.clientY
      const card = modalRef.current
      if (!card) return
      const w = card.offsetWidth
      const h = card.offsetHeight
      let left = clientX - dragState.current.offsetX
      let top = clientY - dragState.current.offsetY
      // clamp inside viewport
      left = Math.max(8, Math.min(left, window.innerWidth - w - 8))
      top = Math.max(8, Math.min(top, window.innerHeight - h - 8))
      setPos({ left, top })
    }
    const onUp = () => {
      if (dragState.current.dragging) {
        dragState.current.dragging = false
        modalRef.current?.classList.remove('mp-dragging')
      }
    }
    window.addEventListener('mousemove', onMove)
    window.addEventListener('mouseup', onUp)
    window.addEventListener('touchmove', onMove, { passive: false })
    window.addEventListener('touchend', onUp)
    return () => {
      window.removeEventListener('mousemove', onMove)
      window.removeEventListener('mouseup', onUp)
      window.removeEventListener('touchmove', onMove)
      window.removeEventListener('touchend', onUp)
    }
  }, [])

  if (!isOpen) return null

  // Card style: if pos is set (dragged or initial anchor), use fixed positioning
  // ponytail: fixed terikat containing-block terdekat (dnd-kit transform di SortableRow)
  // → render via portal ke body agar left/top viewport selalu benar.
  const cardDragStyle = pos ? { left: pos.left, top: pos.top, position: 'fixed', margin: 0 } : undefined
  // For popover that hasn't been dragged yet, pos is already set from anchor; for centered modal, pos=null -> CSS centers via flex
  const cardStyle = isPopover || pos ? cardDragStyle : undefined

  return createPortal(
    <div className={`mp-overlay ${isPopover ? 'mp-overlay-popover' : ''}`} onClick={onClose}>
      <div
        ref={modalRef}
        className={`mp-card ${isPopover ? 'mp-card-popover' : 'mp-card-modal'} ${pos ? 'mp-card-draggable' : ''}`}
        style={cardStyle}
        onClick={(e) => e.stopPropagation()}
        role="dialog"
        aria-modal="true"
      >
        {/* Header - draggable */}
        <div
          className="mp-header mp-header-draggable"
          ref={headerRef}
          onMouseDown={onHeaderPointerDown}
          onTouchStart={onHeaderPointerDown}
          title={isMobile ? undefined : 'Seret untuk memindahkan'}
        >
          <div className="mp-header-left">
            <div className="mp-header-icon">
              <span style={{ fontSize: 16, fontWeight: 800 }}>∑</span>
            </div>
            <div>
              <h3 className="mp-title">Sisipkan Rumus</h3>
              <p className="mp-subtitle">Pilih preset • klik Edit untuk ubah huruf/angka • seret header untuk pindah</p>
            </div>
          </div>
          <div className="mp-header-actions">
            {!isMobile && (
              <span className="mp-drag-hint" aria-hidden="true" title="Seret untuk memindahkan">
                <svg width="14" height="14" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}><circle cx="9" cy="12" r="1" /><circle cx="9" cy="5" r="1" /><circle cx="9" cy="19" r="1" /><circle cx="15" cy="12" r="1" /><circle cx="15" cy="5" r="1" /><circle cx="15" cy="19" r="1" /></svg>
              </span>
            )}
            <button className="mp-close" onClick={onClose} aria-label="Tutup">
              <svg width="16" height="16" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}><line x1="18" y1="6" x2="6" y2="18" /><line x1="6" y1="6" x2="18" y2="18" /></svg>
            </button>
          </div>
        </div>

        {/* Tabs */}
        <div className="mp-tabs">
          <button className={`mp-tab ${activeTab === 'presets' ? 'active' : ''}`} onClick={() => setActiveTab('presets')}>
            <svg width="14" height="14" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}><rect x="3" y="3" width="7" height="7" rx="1" /><rect x="14" y="3" width="7" height="7" rx="1" /><rect x="3" y="14" width="7" height="7" rx="1" /><rect x="14" y="14" width="7" height="7" rx="1" /></svg>
            Presets
          </button>
          <button className={`mp-tab ${activeTab === 'custom' ? 'active' : ''}`} onClick={() => setActiveTab('custom')}>
            <svg width="14" height="14" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}><path d="M12 20h9" /><path d="M16.5 3.5a2.12 2.12 0 013 3L7 19l-4 1 1-4 12.5-12.5z" /></svg>
            Custom LaTeX
          </button>
        </div>

        {/* Inline quick-edit panel (shown when Edit clicked) */}
        {inlineEdit && activeTab === 'presets' && (
          <div className="mp-inline-edit">
            <div className="mp-inline-edit-head">
              <span className="mp-inline-edit-title">
                <svg width="12" height="12" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}><path d="M11 4H4a2 2 0 00-2 2v14a2 2 0 002 2h14a2 2 0 002-2v-7" /><path d="M18.5 2.5a2.12 2.12 0 013 3L12 15l-4 1 1-4 9.5-9.5z" /></svg>
                Edit: {inlineEdit.label}
              </span>
              <button className="mp-inline-close" onClick={() => setInlineEdit(null)} aria-label="Tutup edit">
                <svg width="12" height="12" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.5}><line x1="18" y1="6" x2="6" y2="18" /><line x1="6" y1="6" x2="18" y2="18" /></svg>
              </button>
            </div>
            <div className="mp-inline-edit-desc">Ubah huruf/angka (mis. <code>a</code> → <code>5</code>) lalu Sisipkan. Live preview di bawah.</div>
            <textarea
              className="mp-textarea mp-inline-textarea"
              value={inlineEdit.latex}
              onChange={(e) => setInlineEdit({ ...inlineEdit, latex: e.target.value })}
              rows={2}
              autoFocus
            />
            <label className="mp-toggle-row" style={{ marginTop: 8 }}>
              <input type="checkbox" checked={inlineDisplay} onChange={(e) => setInlineDisplay(e.target.checked)} />
              <span className="mp-toggle-box" />
              <span className="mp-toggle-label">Mode display (block, tengah)</span>
            </label>
            <div className="mp-preview-box" style={{ marginTop: 8 }}>
              <PreviewBox latex={inlineEdit.latex} displayMode={inlineDisplay} />
            </div>
            <div className="mp-inline-actions">
              <button className="mp-btn-secondary" onClick={() => setInlineEdit(null)}>Batal</button>
              <button className="mp-btn-secondary" onClick={() => switchToCustomWithLatex(inlineEdit.latex)}>Buka di Custom →</button>
              <button className="mp-insert-btn mp-inline-insert" onClick={handleInlineInsert} disabled={!inlineEdit.latex.trim()}>
                <svg width="12" height="12" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.5}><polyline points="20 6 9 17 4 12" /></svg>
                Sisipkan
              </button>
            </div>
          </div>
        )}

        {/* Body */}
        <div className="mp-body">
          {activeTab === 'presets' && (
            <>
              <div className="mp-search-wrap">
                <svg width="14" height="14" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}><circle cx="11" cy="11" r="8" /><line x1="21" y1="21" x2="16.5" y2="16.5" /></svg>
                <input
                  className="mp-search-input"
                  placeholder="Cari rumus, simbol, Yunani..."
                  value={search}
                  onChange={(e) => setSearch(e.target.value)}
                />
                {search && (
                  <button className="mp-search-clear" onClick={() => setSearch('')} aria-label="Hapus">
                    <svg width="12" height="12" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.5}><line x1="18" y1="6" x2="6" y2="18" /><line x1="6" y1="6" x2="18" y2="18" /></svg>
                  </button>
                )}
              </div>

              <div className="mp-presets-scroll">
                {filteredPresets.length === 0 ? (
                  <div className="mp-empty">Tidak ada hasil untuk &quot;{search}&quot;</div>
                ) : (
                  filteredPresets.map((cat) => (
                    <div key={cat.category} className="mp-category">
                      <div className="mp-category-title">{cat.category}</div>
                      <div className="mp-preset-grid">
                        {cat.items.map((item) => (
                          <div key={item.label + item.latex} className="mp-preset-wrap">
                            <button
                              className="mp-preset-btn"
                              onClick={() => handlePresetClick(item.latex)}
                              title={`Klik untuk langsung sisipkan: ${item.latex}`}
                            >
                              <span className="mp-preset-display">{item.display}</span>
                              <span className="mp-preset-label">{item.label}</span>
                              <span className="mp-preset-latex">{item.latex}</span>
                            </button>
                            <button
                              className="mp-preset-edit"
                              onClick={() => handleEditClick(item)}
                              title={`Edit ${item.label}: ubah huruf/angka sebelum sisipkan`}
                              aria-label={`Edit ${item.label}`}
                            >
                              <svg width="12" height="12" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}><path d="M11 4H4a2 2 0 00-2 2v14a2 2 0 002 2h14a2 2 0 002-2v-7" /><path d="M18.5 2.5a2.12 2.12 0 013 3L12 15l-4 1 1-4 9.5-9.5z" /></svg>
                              Edit
                            </button>
                          </div>
                        ))}
                      </div>
                    </div>
                  ))
                )}
              </div>
            </>
          )}

          {activeTab === 'custom' && (
            <div className="mp-custom">
              <label className="mp-field-label">Kode LaTeX</label>
              <textarea
                className="mp-textarea"
                value={customLatex}
                onChange={(e) => setCustomLatex(e.target.value)}
                placeholder="Contoh: \frac{a}{b}, \sqrt{x^2 + y^2}, \sum_{i=1}^{n}"
                rows={3}
              />

              <label className="mp-toggle-row">
                <input type="checkbox" checked={isDisplay} onChange={(e) => setIsDisplay(e.target.checked)} />
                <span className="mp-toggle-box" />
                <span className="mp-toggle-label">
                  Mode display (block, tengah) – untuk rumus besar seperti integral/matrik
                </span>
              </label>

              <div className="mp-preview-wrap">
                <div className="mp-preview-label">Pratinjau Live (KaTeX)</div>
                <div className="mp-preview-box">
                  <PreviewBox latex={customLatex} displayMode={isDisplay} />
                </div>
                <div className="mp-preview-hint">
                  Tips: gunakan <code>\frac</code>, <code>\sqrt</code>, <code>^{''}</code>, <code>_{''}</code>, <code>\sum</code>, <code>\int</code> — ubah huruf/angka langsung di atas
                </div>
              </div>

              <button className="mp-insert-btn" onClick={handleCustomInsert} disabled={!customLatex.trim()}>
                <svg width="14" height="14" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}><path d="M12 5v14M5 12h14" /></svg>
                Sisipkan Rumus
              </button>
            </div>
          )}
        </div>

        {/* Footer hint */}
        <div className="mp-footer">
          <span>💡 Klik rumus untuk sisipkan langsung • Klik <b>Edit</b> untuk ubah huruf/angka • Seret header untuk pindahkan modal</span>
        </div>
      </div>
    </div>,
    document.body
  )
}
