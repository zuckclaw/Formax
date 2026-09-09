import { useRef, useEffect, useState, useCallback } from 'react'
import ReactQuill, { Quill } from 'react-quill-new'
import 'react-quill-new/dist/quill.snow.css'
import { uploadFile } from '../api/uploads'
import { apiFetch } from '../api/config'
import katex from 'katex'
import 'katex/dist/katex.min.css'
import hljs from 'highlight.js'
import 'highlight.js/styles/atom-one-dark.min.css'
import ImageResize from '@mgreminger/quill-image-resize-module'
import MathPicker from './MathPicker'
import VideoLinkModal from './VideoLinkModal'
import { parseVideoUrl, enhanceVideoContainers } from '../utils/videoEmbed'
import '../styles/video-embed.css'

if (typeof window !== 'undefined') {
  window.katex = katex
  window.hljs = hljs
}

// Register custom fonts
const Font = Quill.import('formats/font')
Font.whitelist = [
  false,
  'inter',
  'roboto',
  'poppins',
  'montserrat',
  'open-sans',
  'lato',
  'nunito',
  'raleway',
  'source-code-pro',
  'fira-code',
  'jetbrains-mono',
  'arial',
  'georgia',
  'times-new-roman',
  'courier-new',
  'comic-sans',
]
Quill.register(Font, true)

// Register custom sizes
const Size = Quill.import('formats/size')
Size.whitelist = ['10px', '12px', '14px', '16px', '18px', '20px', '24px', '28px', '32px', '36px', '48px']
Quill.register(Size, true)

// Register image resize module
Quill.register('modules/imageResize', ImageResize)

// ── Custom Display Math Blot (block, centered) ───────────────────────────────
const BlockEmbed2 = Quill.import('blots/block/embed')
class DisplayMathBlot extends BlockEmbed2 {
  static create({ latex, html }) {
    const node = super.create()
    node.setAttribute('data-latex', latex)
    node.classList.add('math-display-block')
    // rendered html already safe (katex output)
    node.innerHTML = html
    return node
  }
  static value(node) {
    return node.getAttribute('data-latex') || ''
  }
}
DisplayMathBlot.blotName = 'displayMath'
DisplayMathBlot.tagName = 'div'
Quill.register(DisplayMathBlot)

// ── Custom Image Blot ────────────────────────────────────────────────────────
const ImageBlot = Quill.import('formats/image')
class CustomImageBlot extends ImageBlot {
  static value(node) {
    // Preserve originalSrc if ngrok blob patch was applied
    return node.dataset?.originalSrc || node.getAttribute('src')
  }
}
Quill.register(CustomImageBlot, true)
// ─────────────────────────────────────────────────────────────────────────────

// ── Custom Audio Blot ────────────────────────────────────────────────────────
const BlockEmbed = Quill.import('blots/block/embed')

class AudioBlot extends BlockEmbed {
  static create(url) {
    const node = super.create()
    node.setAttribute('controls', true)
    node.setAttribute('src', url)
    node.setAttribute('style', 'width:100%;margin:8px 0;border-radius:8px;')
    return node
  }

  static value(node) {
    // Fix hilang setelah Simpan: jika src sudah jadi blob:URL karena ngrok patch,
    // kembalikan originalSrc agar yang tersimpan di DB tetap ngrok URL
    return node.dataset?.originalSrc || node.getAttribute('src')
  }
}
AudioBlot.blotName = 'audio'
AudioBlot.tagName = 'audio'
Quill.register(AudioBlot)
// ── Custom Video Embed Blot (sanitizer-safe div[data-video]) ───────────────
class VideoEmbedBlot extends BlockEmbed {
  static create(rawUrl) {
    const node = super.create()
    const url = String(rawUrl || '').trim()
    const parsed = parseVideoUrl(url)
    const embed = parsed ? parsed.embedUrl : url
    const type = parsed ? parsed.type : 'unknown'
    node.classList.add('video-embed')
    node.setAttribute('data-video', url)
    node.setAttribute('data-embed', embed)
    node.setAttribute('data-type', type)
    node.setAttribute('contenteditable', 'false')
    // placeholder text inside for quill delta
    node.innerHTML = `<span style="display:inline-block;padding:6px 10px;background:#eff6ff;border:1px dashed #93c5fd;border-radius:8px;color:#2563eb;font-size:12px;">&#9654; Video: ${escapeHtml(url.slice(0,60))}</span>`
    return node
  }
  static value(node) {
    return node.getAttribute('data-video') || ''
  }
}
VideoEmbedBlot.blotName = 'videoEmbed'
VideoEmbedBlot.tagName = 'div'
Quill.register(VideoEmbedBlot)
function escapeHtml(s) {
  return String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;')
}
// ─────────────────────────────────────────────────────────────────────────────

// ── Custom Image Upload Handler ──────────────────────────────────────────────
const handleImageUpload = function () {
  const quill = this.quill
  const input = document.createElement('input')
  input.setAttribute('type', 'file')
  input.setAttribute('accept', 'image/*')
  input.click()

  input.onchange = async () => {
    const file = input.files[0]
    if (!file) return

    const token = localStorage.getItem('token')
    const range = quill.getSelection(true)
    const index = range ? range.index : (quill.getLength() || 0)

    try {
      const result = await uploadFile(token, file)
      const url = result?.file_url
      if (url) {
        quill.insertEmbed(index, 'image', url, 'user')
        quill.setSelection(index + 1, 0)
      } else {
        alert('Gagal mengunggah gambar: URL file tidak ditemukan dalam respons server.')
      }
    } catch (err) {
      alert('Gagal mengunggah gambar: ' + err.message)
    }
  }
}
// ─────────────────────────────────────────────────────────────────────────────

// ── Custom Audio Upload Handler ──────────────────────────────────────────────
const handleAudioUpload = function () {
  const quill = this.quill
  const input = document.createElement('input')
  input.setAttribute('type', 'file')
  input.setAttribute('accept', 'audio/*')
  input.click()

  input.onchange = async () => {
    const file = input.files[0]
    if (!file) return

    const token = localStorage.getItem('token')
    const range = quill.getSelection(true)
    const index = range ? range.index : (quill.getLength() || 0)

    try {
      const result = await uploadFile(token, file)
      const url = result?.file_url
      if (url) {
        quill.insertEmbed(index, 'audio', url, 'user')
        quill.setSelection(index + 1, 0)
      } else {
        alert('Gagal mengunggah audio: URL file tidak ditemukan dalam respons server.')
      }
    } catch (err) {
      alert('Gagal mengunggah audio: ' + err.message)
    }
  }
}

// Video handler dipindah ke dalam komponen (modal) — lihat RichTextEditor bawah
// ─────────────────────────────────────────────────────────────────────────────

// Full toolbar for form description
const FULL_MODULES = {
  toolbar: {
    container: [
      [{ font: Font.whitelist }, { size: Size.whitelist }, { header: [1, 2, 3, false] }],
      ['bold', 'italic', 'underline', 'strike'],
      [{ color: [] }, { background: [] }],
      ['code-block', 'blockquote'],
      [{ list: 'ordered' }, { list: 'bullet' }, { align: [] }],
      ['link', 'image', 'video', 'audio'],
      ['formula', 'math'],
      ['clean'],
    ],
    handlers: {
      image: handleImageUpload,
      audio: handleAudioUpload,
      // video handler di-inject via useEffect (modal kustom)
    },
  },
  syntax: { hljs },
  imageResize: {
    modules: ['Resize', 'DisplaySize'],
    minWidth: 20,
  },
}

// Compact toolbar for question labels
const QUESTION_MODULES = {
  toolbar: {
    container: [
      [{ font: Font.whitelist }, { size: Size.whitelist }],
      ['bold', 'italic', 'underline', 'strike'],
      [{ color: [] }, { background: [] }],
      ['code-block', 'blockquote'],
      [{ list: 'ordered' }, { list: 'bullet' }],
      ['link', 'image', 'video', 'audio'],
      ['formula', 'math'],
      ['clean'],
    ],
    handlers: {
      image: handleImageUpload,
      audio: handleAudioUpload,
      // video handler di-inject via useEffect (modal kustom)
    },
  },
  syntax: { hljs },
  imageResize: {
    modules: ['Resize', 'DisplaySize'],
    minWidth: 20,
  },
}

// Option toolbar for answer choices
const OPTION_MODULES = {
  toolbar: {
    container: [
      [{ size: Size.whitelist }],
      ['bold', 'italic', 'underline', 'strike'],
      [{ color: [] }],
      ['image'],
      ['formula', 'math'],
      ['clean'],
    ],
    handlers: {
      image: handleImageUpload,
    },
  },
  imageResize: {
    modules: ['Resize', 'DisplaySize'],
    minWidth: 20,
  },
}

const FORMATS = [
  'font', 'size', 'header',
  'bold', 'italic', 'underline', 'strike',
  'color', 'background',
  'script',
  'blockquote', 'code-block',
  'list', 'indent', 'direction', 'align',
  'link', 'image', 'video', 'videoEmbed', 'formula',
  'audio', 'displayMath',
]

/**
 * Reusable Rich Text Editor component.
 * @param {object} props
 * @param {string} props.value - Current HTML value
 * @param {function} props.onChange - Callback when value changes
 * @param {string} [props.placeholder] - Placeholder text
 * @param {string} [props.className] - Extra CSS class
 * @param {'full'|'compact'|'option'} [props.variant] - Toolbar variant: 'full', 'compact', or 'option'
 */
const RichTextEditor = ({ value, onChange, placeholder, className, variant = 'full' }) => {
  const quillRef = useRef(null)
  const modules = variant === 'option' ? OPTION_MODULES : (variant === 'compact' ? QUESTION_MODULES : FULL_MODULES)
  const [mathOpen, setMathOpen] = useState(false)
  const [anchorRect, setAnchorRect] = useState(null)
  const savedRangeRef = useRef(null)
  const mathBtnRef = useRef(null)
  const [videoOpen, setVideoOpen] = useState(false)
  const videoRangeRef = useRef(null)

  const handleVideoConfirm = useCallback((rawUrl) => {
    const quill = quillRef.current?.getEditor()
    if (!quill) return
    const parsed = parseVideoUrl(String(rawUrl || '').trim())
    if (!parsed) return
    const range = videoRangeRef.current || savedRangeRef.current || quill.getSelection(true) || { index: quill.getLength(), length: 0 }
    const index = range.index ?? quill.getLength()
    quill.insertEmbed(index, 'videoEmbed', parsed.original, 'user')
    quill.setSelection(index + 1, 0, 'user')
    quill.focus()
    setTimeout(() => {
      try { enhanceVideoContainers(quill.root) } catch {}
    }, 50)
  }, [])

  const handleMathInsert = useCallback((latex, displayMode) => {
    const quill = quillRef.current?.getEditor()
    if (!quill) return
    const range = savedRangeRef.current || quill.getSelection(true) || { index: quill.getLength(), length: 0 }
    const index = range.index
    try {
      if (displayMode) {
        // Render display mode HTML and insert as block embed
        const html = katex.renderToString(latex, { throwOnError: false, displayMode: true, strict: false })
        // Ensure we are at line boundary: insert newline if needed
        const needPrefixNewline = index > 0 && quill.getText(index - 1, 1) !== '\n'
        let insertAt = index
        if (needPrefixNewline) {
          quill.insertText(insertAt, '\n', 'user')
          insertAt += 1
        }
        quill.insertEmbed(insertAt, 'displayMath', { latex, html }, 'user')
        quill.setSelection(insertAt + 1, 0, 'user')
      } else {
        // Inline formula - use native formula embed
        // Validate
        katex.renderToString(latex, { throwOnError: false, displayMode: false })
        quill.insertEmbed(index, 'formula', latex, 'user')
        quill.setSelection(index + 1, 0, 'user')
      }
      quill.focus()
    } catch (err) {
      console.error('[MathInsert] gagal:', err)
    }
    setMathOpen(false)
  }, [])

  // Inject audio, image, math, formula button title/icon into toolbar after mount
  useEffect(() => {
    const editor = quillRef.current
    if (!editor) return
    const quill = editor.getEditor()
    const toolbar = quill.getModule('toolbar')
    const toolbarEl = toolbar.container

    // Video handler → buka modal kustom (bukan prompt)
    toolbar.addHandler('video', function () {
      const sel = this.quill.getSelection(true)
      const range = sel ? { ...sel } : { index: this.quill.getLength(), length: 0 }
      videoRangeRef.current = range
      savedRangeRef.current = range
      setVideoOpen(true)
    })

    // Register handlers for math & formula to open picker
    toolbar.addHandler('math', function () {
      // 'this' is toolbar, quill is this.quill
      const sel = this.quill.getSelection(true)
      savedRangeRef.current = sel ? { ...sel } : { index: this.quill.getLength(), length: 0 }
      const btn = toolbarEl.querySelector('.ql-math')
      setAnchorRect(btn ? btn.getBoundingClientRect() : null)
      if (btn) mathBtnRef.current = btn
      setMathOpen(true)
    })
    toolbar.addHandler('formula', function () {
      const sel = this.quill.getSelection(true)
      savedRangeRef.current = sel ? { ...sel } : { index: this.quill.getLength(), length: 0 }
      const btn = toolbarEl.querySelector('.ql-formula') || toolbarEl.querySelector('.ql-math')
      setAnchorRect(btn ? btn.getBoundingClientRect() : null)
      if (btn) mathBtnRef.current = btn
      setMathOpen(true)
    })

    const audioBtns = toolbarEl.querySelectorAll('.ql-audio')
    audioBtns.forEach((btn) => {
      if (!btn.innerHTML.trim()) {
        btn.innerHTML = `<svg viewBox="0 0 24 24" width="16" height="16" fill="currentColor"><path d="M12 3v10.55A4 4 0 1 0 14 17V7h4V3h-6z"/></svg>`
      }
      btn.title = 'Sisipkan Audio'
    })
    const imageBtns = toolbarEl.querySelectorAll('.ql-image')
    imageBtns.forEach((btn) => {
      btn.title = 'Sisipkan Gambar'
    })
    const videoBtns = toolbarEl.querySelectorAll('.ql-video')
    videoBtns.forEach((btn) => {
      btn.title = 'Sisipkan Video (YouTube/Vimeo/Drive/MP4)'
    })
    // Style math button (fx)
    const mathBtns = toolbarEl.querySelectorAll('.ql-math')
    mathBtns.forEach((btn) => {
      mathBtnRef.current = btn
      btn.innerHTML = `<span style="font-weight:800;font-size:13px;letter-spacing:-0.5px;">fx</span>`
      btn.title = 'Sisipkan Rumus (∑)'
      btn.addEventListener('click', () => {
        // handler already via toolbar.addHandler, but ensure anchor
        const sel = quill.getSelection(true)
        savedRangeRef.current = sel ? { ...sel } : { index: quill.getLength(), length: 0 }
        setAnchorRect(btn.getBoundingClientRect())
      })
    })
    // Also style native formula button to same fx if math not present (fallback)
    const formulaBtns = toolbarEl.querySelectorAll('.ql-formula')
    formulaBtns.forEach((btn) => {
      if (!btn.dataset.styled) {
        btn.dataset.styled = '1'
        // Keep original but also ensure title
        btn.title = 'Sisipkan Rumus (∑) – klik untuk picker'
        // If there's no ql-math (fallback), style formula as fx
        if (!toolbarEl.querySelector('.ql-math')) {
          btn.innerHTML = `<span style="font-weight:800;font-size:13px;letter-spacing:-0.5px;">fx</span>`
        }
      }
    })
  }, [])

  // Auto-enhance video embeds inside editor (render div.video-embed → iframe/video)
  // Juga handle paste bare URL → auto convert ke videoEmbed blot
  useEffect(() => {
    const editor = quillRef.current?.getEditor()
    if (!editor) return
    const root = editor.root
    // Enhance stored video placeholders
    try { enhanceVideoContainers(root) } catch {}
    // Paste handler: intercept text paste yang berisi link video → convert to embed
    const handlePaste = () => {
      // delay to let quill insert text first
      setTimeout(() => {
        try {
          // scan root text nodes for bare video URLs that slipped through as plain text/link
          enhanceVideoContainers(root)
          // Also convert bare text URLs that exist as text nodes inside root (e.g., "https://youtu.be/...")
          // Find text containing video domain and convert via quill API? Simplistic: if plain text url detected without <a>, replace via DOM then sync to onChange via quill update
          const html = root.innerHTML
          if (/(youtube\.com|youtu\.be|vimeo\.com|drive\.google\.com)/i.test(html) && html.includes('http')) {
            // enhance already converts anchors; for plain text we rely on DOM text scanning in enhanceVideoContainers fallback
            // If still plain text remains, try to convert by checking root innerText
            const text = root.innerText || ''
            const urlRe = /https?:\/\/[^\s]+/gi
            let m
            while ((m = urlRe.exec(text)) !== null) {
              const parsed = parseVideoUrl(m[0])
              if (parsed) {
                // trigger enhance again for any newly created anchors (quill may have auto-linked)
                enhanceVideoContainers(root)
                // Notify parent of HTML change (so saved value includes embed)
                const newHtml = root.innerHTML
                if (newHtml !== html && onChange) onChange(newHtml)
                break
              }
            }
          }
        } catch {}
      }, 30)
    }
    root.addEventListener('paste', handlePaste)
    // Also observe mutations to auto-enhance when value prop changes externally
    const mo = new MutationObserver(() => { try { enhanceVideoContainers(root) } catch {} })
    mo.observe(root, { childList: true, subtree: true })
    return () => {
      root.removeEventListener('paste', handlePaste)
      mo.disconnect()
    }
  }, [value, onChange])

  // Fix media (audio & image) ngrok di dalam editor preview (builder)
  useEffect(() => {
    const editor = quillRef.current?.getEditor()
    if (!editor || !value || !value.includes('ngrok-free')) return
    const root = editor.root
    const mediaElements = root.querySelectorAll('audio[src*="ngrok-free"], img[src*="ngrok-free"]')
    if (mediaElements.length === 0) return
    const controllers = []

    mediaElements.forEach((el) => {
      const src = el.getAttribute('src')
      if (!src || src.startsWith('data:') || src.startsWith('blob:') || el.dataset.ngrokFixed) return
      el.dataset.ngrokFixed = '1'
      el.dataset.originalSrc = src
      const controller = new AbortController()
      controllers.push(controller)
      el.style.opacity = '0.6'
      apiFetch(src, { signal: controller.signal })
        .then((res) => {
          if (!res.ok) throw new Error(`HTTP ${res.status}`)
          return res.blob()
        })
        .then((blob) => {
          if (blob.type && blob.type.startsWith('text/html')) throw new Error('Ngrok HTML')
          const blobUrl = URL.createObjectURL(blob)
          el.src = blobUrl
          if (el.tagName === 'AUDIO') el.load()
          el.style.opacity = '1'
          el.dataset.blobUrl = blobUrl
        })
        .catch((err) => {
          if (err.name === 'AbortError') return
          console.error('[RichTextEditor NgrokMedia] gagal:', src, err)
          el.style.opacity = '1'
        })
    })

    return () => {
      controllers.forEach((c) => c.abort())
    }
  }, [value])

  return (
    <>
      <ReactQuill
        ref={quillRef}
        theme="snow"
        value={value}
        onChange={onChange}
        placeholder={placeholder}
        modules={modules}
        formats={FORMATS}
        className={className}
      />
      <MathPicker
        isOpen={mathOpen}
        onClose={() => setMathOpen(false)}
        onInsert={handleMathInsert}
        anchorRect={anchorRect}
      />
      <VideoLinkModal
        isOpen={videoOpen}
        onClose={() => setVideoOpen(false)}
        onInsert={handleVideoConfirm}
      />
    </>
  )
}

export default RichTextEditor
