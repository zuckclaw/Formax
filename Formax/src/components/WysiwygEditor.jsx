import { useRef, useEffect, useState } from 'react'

const WysiwygEditor = ({ value, onChange, placeholder, className, style }) => {
  const editorRef = useRef(null)
  const [isFocused, setIsFocused] = useState(false)
  const [showTextColor, setShowTextColor] = useState(false)
  const [showBgColor, setShowBgColor] = useState(false)
  const [showHeaderDropdown, setShowHeaderDropdown] = useState(false)
  const [currentHeaderLabel, setCurrentHeaderLabel] = useState('Normal')

  const [showFontSizeDropdown, setShowFontSizeDropdown] = useState(false)
  const [currentFontSizeLabel, setCurrentFontSizeLabel] = useState('14px')

  const applyHeader = (tag, label) => {
    setCurrentHeaderLabel(label)
    try {
      document.execCommand('formatBlock', false, `<${tag}>`)
    } catch (e) {
      document.execCommand('formatBlock', false, tag)
    }
    handleInput()
    editorRef.current?.focus()
  }

  const applyFontSize = (sizePx) => {
    setCurrentFontSizeLabel(`${sizePx}px`)
    document.execCommand('fontSize', false, '7')
    if (editorRef.current) {
      const fontElements = editorRef.current.getElementsByTagName('font')
      const fonts = Array.from(fontElements)
      fonts.forEach(font => {
        if (font.getAttribute('size') === '7') {
          const span = document.createElement('span')
          span.style.fontSize = `${sizePx}px`
          span.innerHTML = font.innerHTML
          font.parentNode.replaceChild(span, font)
        }
      })
      handleInput()
      editorRef.current.focus()
    }
  }

  // Sync value from parent if it changes externally and differs from current editor content
  useEffect(() => {
    if (editorRef.current && editorRef.current.innerHTML !== (value || '')) {
      editorRef.current.innerHTML = value || ''
    }
  }, [value])

  const handleInput = () => {
    if (editorRef.current) {
      onChange(editorRef.current.innerHTML)
    }
  }

  const execCommand = (command, val = null) => {
    document.execCommand(command, false, val)
    handleInput()
    editorRef.current?.focus()
  }

  const handleLink = () => {
    const url = prompt('Masukkan URL Link:')
    if (url) {
      execCommand('createLink', url)
    }
  }

  // Prevent blur when clicking toolbar buttons
  const handleToolbarMouseDown = (e) => {
    e.preventDefault()
  }

  const colors = [
    { name: 'Default', hex: '#0f172a' },
    { name: 'Blue', hex: '#2563eb' },
    { name: 'Red', hex: '#dc2626' },
    { name: 'Green', hex: '#16a34a' },
    { name: 'Orange', hex: '#ea580c' },
    { name: 'Purple', hex: '#9333ea' }
  ]

  const bgColors = [
    { name: 'None', hex: 'transparent' },
    { name: 'Yellow Highlight', hex: '#fef08a' },
    { name: 'Green Highlight', hex: '#bbf7d0' },
    { name: 'Blue Highlight', hex: '#bfdbfe' },
    { name: 'Red Highlight', hex: '#fecaca' },
    { name: 'Purple Highlight', hex: '#e9d5ff' }
  ]

  return (
    <div className={`ql-like-container ${isFocused ? 'ql-focused' : ''}`}>
      {/* Quill-style Toolbar */}
      <div 
        className="ql-like-toolbar"
        onMouseDown={handleToolbarMouseDown}
      >
        {/* Header Block Selector Popover */}
        <div style={{ position: 'relative' }}>
          <button 
            type="button" 
            onClick={() => { setShowHeaderDropdown(!showHeaderDropdown); setShowTextColor(false); setShowBgColor(false); }} 
            className="ql-header-trigger"
            title="Format Ukuran Teks / Header"
          >
            <span>{currentHeaderLabel}</span>
            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
              <polyline points="6 9 12 15 18 9" />
            </svg>
          </button>
          {showHeaderDropdown && (
            <div className="ql-header-dropdown">
              <button 
                type="button" 
                onClick={() => { applyHeader('p', 'Normal'); setShowHeaderDropdown(false); }}
                className={`ql-header-option ${currentHeaderLabel === 'Normal' ? 'active' : ''}`}
              >
                Normal
              </button>
              <button 
                type="button" 
                onClick={() => { applyHeader('h1', 'Heading 1'); setShowHeaderDropdown(false); }}
                className={`ql-header-option h1-opt ${currentHeaderLabel === 'Heading 1' ? 'active' : ''}`}
              >
                Heading 1
              </button>
              <button 
                type="button" 
                onClick={() => { applyHeader('h2', 'Heading 2'); setShowHeaderDropdown(false); }}
                className={`ql-header-option h2-opt ${currentHeaderLabel === 'Heading 2' ? 'active' : ''}`}
              >
                Heading 2
              </button>
              <button 
                type="button" 
                onClick={() => { applyHeader('h3', 'Heading 3'); setShowHeaderDropdown(false); }}
                className={`ql-header-option h3-opt ${currentHeaderLabel === 'Heading 3' ? 'active' : ''}`}
              >
                Heading 3
              </button>
            </div>
          )}
        </div>

        {/* Font Size Selector Popover */}
        <div style={{ position: 'relative', marginLeft: '4px' }}>
          <button 
            type="button" 
            onClick={() => { setShowFontSizeDropdown(!showFontSizeDropdown); setShowHeaderDropdown(false); setShowTextColor(false); setShowBgColor(false); }} 
            className="ql-header-trigger font-size-trigger"
            title="Ukuran Font (px)"
          >
            <span>{currentFontSizeLabel}</span>
            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
              <polyline points="6 9 12 15 18 9" />
            </svg>
          </button>
          {showFontSizeDropdown && (
            <div className="ql-header-dropdown font-size-dropdown">
              {[12, 14, 16, 18, 20, 24, 30, 36].map((size) => (
                <button 
                  key={size}
                  type="button" 
                  onClick={() => { applyFontSize(size); setShowFontSizeDropdown(false); }}
                  className={`ql-header-option ${currentFontSizeLabel === `${size}px` ? 'active' : ''}`}
                  style={{ fontSize: `${Math.min(18, size)}px` }}
                >
                  {size}px
                </button>
              ))}
            </div>
          )}
        </div>

        <div className="ql-separator"></div>

        {/* Inline Formatting Actions */}
        <button 
          type="button" 
          onClick={() => execCommand('bold')} 
          className="ql-btn" 
          title="Tebal (Ctrl+B)"
        >
          <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
            <path d="M6 4h8a4 4 0 0 1 4 4 4 4 0 0 1-4 4H6z" />
            <path d="M6 12h9a4 4 0 0 1 4 4 4 4 0 0 1-4 4H6z" />
          </svg>
        </button>

        <button 
          type="button" 
          onClick={() => execCommand('italic')} 
          className="ql-btn" 
          title="Miring (Ctrl+I)"
        >
          <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
            <line x1="19" y1="4" x2="10" y2="4" />
            <line x1="14" y1="20" x2="5" y2="20" />
            <line x1="15" y1="4" x2="9" y2="20" />
          </svg>
        </button>

        <button 
          type="button" 
          onClick={() => execCommand('underline')} 
          className="ql-btn" 
          title="Garis Bawah (Ctrl+U)"
        >
          <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
            <path d="M6 3v7a6 6 0 0 0 6 6 6 6 0 0 0 6-6V3" />
            <line x1="4" y1="21" x2="20" y2="21" />
          </svg>
        </button>

        <button 
          type="button" 
          onClick={() => execCommand('strikeThrough')} 
          className="ql-btn" 
          title="Coret (Strikethrough)"
        >
          <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
            <path d="M16 4H9a3 3 0 0 0-2.83 4H19a3 3 0 0 0-2.83-4z" />
            <path d="M14 20h7a3 3 0 0 0 2.83-4H5a3 3 0 0 0 2.83 4z" />
            <line x1="4" y1="12" x2="20" y2="12" />
          </svg>
        </button>

        <div className="ql-separator"></div>

        {/* Text Alignment */}
        <button 
          type="button" 
          onClick={() => execCommand('justifyLeft')} 
          className="ql-btn" 
          title="Rata Kiri"
        >
          <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
            <line x1="17" y1="10" x2="3" y2="10" />
            <line x1="21" y1="6" x2="3" y2="6" />
            <line x1="21" y1="14" x2="3" y2="14" />
            <line x1="17" y1="18" x2="3" y2="18" />
          </svg>
        </button>

        <button 
          type="button" 
          onClick={() => execCommand('justifyCenter')} 
          className="ql-btn" 
          title="Rata Tengah"
        >
          <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
            <line x1="18" y1="10" x2="6" y2="10" />
            <line x1="21" y1="6" x2="3" y2="6" />
            <line x1="21" y1="14" x2="3" y2="14" />
            <line x1="18" y1="18" x2="6" y2="18" />
          </svg>
        </button>

        <button 
          type="button" 
          onClick={() => execCommand('justifyRight')} 
          className="ql-btn" 
          title="Rata Kanan"
        >
          <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
            <line x1="21" y1="10" x2="7" y2="10" />
            <line x1="21" y1="6" x2="3" y2="6" />
            <line x1="21" y1="14" x2="3" y2="14" />
            <line x1="21" y1="18" x2="7" y2="18" />
          </svg>
        </button>

        <div className="ql-separator"></div>

        {/* Lists */}
        <button 
          type="button" 
          onClick={() => execCommand('insertUnorderedList')} 
          className="ql-btn" 
          title="Bullet List"
        >
          <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
            <line x1="8" y1="6" x2="21" y2="6" />
            <line x1="8" y1="12" x2="21" y2="12" />
            <line x1="8" y1="18" x2="21" y2="18" />
            <line x1="3" y1="6" x2="3.01" y2="6" />
            <line x1="3" y1="12" x2="3.01" y2="12" />
            <line x1="3" y1="18" x2="3.01" y2="18" />
          </svg>
        </button>

        <button 
          type="button" 
          onClick={() => execCommand('insertOrderedList')} 
          className="ql-btn" 
          title="Numbered List"
        >
          <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
            <line x1="10" y1="6" x2="21" y2="6" />
            <line x1="10" y1="12" x2="21" y2="12" />
            <line x1="10" y1="18" x2="21" y2="18" />
            <path d="M4 6H3V5h1v1zm0 7H3v-1h1v1zm0 5H3v-1h1v1z" />
          </svg>
        </button>

        <div className="ql-separator"></div>

        {/* Color Popovers */}
        <div style={{ position: 'relative' }}>
          <button 
            type="button" 
            onClick={() => { setShowTextColor(!showTextColor); setShowBgColor(false); }} 
            className="ql-btn color-trigger" 
            title="Warna Teks"
          >
            <span className="color-icon">A</span>
            <span className="color-bar" style={{ background: '#2563eb' }}></span>
          </button>
          {showTextColor && (
            <div className="ql-color-dropdown">
              {colors.map((c) => (
                <button
                  key={c.hex}
                  type="button"
                  onClick={() => { execCommand('foreColor', c.hex); setShowTextColor(false); }}
                  style={{ backgroundColor: c.hex }}
                  className="ql-color-cell"
                  title={c.name}
                />
              ))}
            </div>
          )}
        </div>

        <div style={{ position: 'relative' }}>
          <button 
            type="button" 
            onClick={() => { setShowBgColor(!showBgColor); setShowTextColor(false); }} 
            className="ql-btn color-trigger" 
            title="Warna Latar Belakang Teks"
          >
            <span className="color-icon bg-icon">✏️</span>
          </button>
          {showBgColor && (
            <div className="ql-color-dropdown">
              {bgColors.map((c) => (
                <button
                  key={c.hex}
                  type="button"
                  onClick={() => { execCommand('hiliteColor', c.hex); setShowBgColor(false); }}
                  style={{ backgroundColor: c.hex === 'transparent' ? '#fff' : c.hex }}
                  className={`ql-color-cell ${c.hex === 'transparent' ? 'cell-transparent' : ''}`}
                  title={c.name}
                />
              ))}
            </div>
          )}
        </div>

        <div className="ql-separator"></div>

        {/* Link & Clear format */}
        <button 
          type="button" 
          onClick={handleLink} 
          className="ql-btn" 
          title="Sisipkan Link"
        >
          <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
            <path d="M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71" />
            <path d="M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71" />
          </svg>
        </button>

        <button 
          type="button" 
          onClick={() => execCommand('removeFormat')} 
          className="ql-btn" 
          title="Hapus Format (Tₓ)"
        >
          <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
            <line x1="18" y1="20" x2="6" y2="20" />
            <path d="M4 12V4h16v8" />
            <line x1="12" y1="4" x2="12" y2="20" />
          </svg>
        </button>
      </div>

      {/* Editor Body */}
      <div
        ref={editorRef}
        className={`ql-like-editor ${className}`}
        style={style}
        contentEditable
        onInput={handleInput}
        onFocus={() => setIsFocused(true)}
        onBlur={() => {
          // Allow clicks on popovers to process before hiding
          setTimeout(() => {
            setIsFocused(false)
            setShowTextColor(false)
            setShowBgColor(false)
            setShowHeaderDropdown(false)
            setShowFontSizeDropdown(false)
          }, 250)
        }}
        data-placeholder={placeholder}
      />
    </div>
  )
}

export default WysiwygEditor
