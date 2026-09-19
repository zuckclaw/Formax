import katex from 'katex'
import { prepareCodeHtml } from './codeRender'

// Regex ringan tanpa nested catastrophic: cukup tangkap \command + 0-2 blok {..}
// + pangkat/subscript plain seperti 9^{10}, x_{i}, x^{n}_{i} (tanpa \)
const SIMPLE_LATEX = /\\[a-zA-Z]+\s*(?:\{[^}]*\}\s*){0,2}/g
const HAS_LATEX = /\\[a-zA-Z]/
const PLAIN_POW_SUB = /[0-9a-zA-Z]\s*(?:\^\{[^}]+\}|_\{[^}]+\})(?:\s*(?:\^\{[^}]+\}|_\{[^}]+\}))*/g
const HAS_POW_SUB = /(?:\^\{[^}]+\}|_\{[^}]+\})/

function renderFragment(latex) {
  try {
    const html = katex.renderToString(latex.trim(), { throwOnError: false, displayMode: false, strict: false })
    if (html.includes('katex-error')) return null
    return html
  } catch {
    return null
  }
}

function escapeHtml(s) {
  return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;')
}

// Pembatas eksplisit \(...\) (inline) dan \[...\] (display) ala LaTeX.
// WAJIB didahulukan dari pencocokan fragmen: seluruh isi dirender utuh
// agar \(...\) tidak tampil sebagai teks plain.
const INLINE_DELIM_RE = /\\\((.+?)\\\)/g
const DISPLAY_DELIM_RE = /\\\[([\s\S]+?)\\\]/g

function renderDelimited(latex, displayMode) {
  try {
    const html = katex.renderToString(latex.trim(), { throwOnError: false, displayMode, strict: false })
    if (!html || html.includes('katex-error')) return null
    return html
  } catch {
    return null
  }
}

function enrichTextChunk(text) {
  if (!text) return null
  // Normalisasi delimiter ganda (model kadang menulis \\( \\)): hanya bila
  // diikuti ( ) [ ] agar \\frac yang benar tidak tersentuh.
  const norm = text.replace(/\\\\([()\[\]])/g, '\\$1')
  const hasDelim = norm.includes('\\(') || norm.includes('\\[')
  const hasLatex = HAS_LATEX.test(norm)
  const hasPow = HAS_POW_SUB.test(norm)
  // reset lastIndex untuk test global
  HAS_POW_SUB.lastIndex = 0
  if (!hasDelim && !hasLatex && !hasPow) return null
  text = norm

  // 1. Kumpulkan span delimiter dulu (prioritas tertinggi, render utuh).
  const frags = []
  let m
  DISPLAY_DELIM_RE.lastIndex = 0
  while ((m = DISPLAY_DELIM_RE.exec(text)) !== null) {
    let inner = (m[1] || '').trim()
    if (inner.length < 1) continue
    inner = inner.replace(/<br\s*\/?>/gi, ' ')
    frags.push({ kind: 'display', frag: inner, raw: m[0], start: m.index, end: m.index + m[0].length })
  }
  INLINE_DELIM_RE.lastIndex = 0
  while ((m = INLINE_DELIM_RE.exec(text)) !== null) {
    if (frags.some(r => m.index >= r.start && m.index < r.end)) continue
    let inner = (m[1] || '').trim()
    if (inner.length < 1) continue
    // <br> mentah di dalam rumus → spasi (KaTeX akan mengartikan < > sebagai simbol)
    inner = inner.replace(/<br\s*\/?>/gi, ' ')
    // Rumus multi-baris (pemisah \\ atau environment aligned/matrix/cases)
    // JANGAN render inline (akan menumpuk vertikal di pil opsi) → promosikan
    // menjadi display block yang bisa scroll horizontal.
    const multi = /\\\\|\\begin\{/.test(inner)
    frags.push({ kind: multi ? 'display' : 'inline', frag: inner, raw: m[0], start: m.index, end: m.index + m[0].length })
  }

  // 2. Fragmen perintah/pangkat hanya di luar span delimiter.
  const insideDelim = (idx) => frags.some(r => idx >= r.start && idx < r.end)
  SIMPLE_LATEX.lastIndex = 0
  while ((m = SIMPLE_LATEX.exec(text)) !== null) {
    if (insideDelim(m.index)) continue
    const f = m[0].trim()
    if (f.length < 3) continue
    frags.push({ kind: 'frag', frag: f, raw: m[0], start: m.index, end: m.index + m[0].length })
  }
  PLAIN_POW_SUB.lastIndex = 0
  while ((m = PLAIN_POW_SUB.exec(text)) !== null) {
    if (insideDelim(m.index)) continue
    const f = m[0].trim()
    if (f.length < 3) continue
    // hindari duplikat yang sudah tercakup oleh SIMPLE_LATEX (overlap)
    const overlap = frags.some(r => m.index >= r.start && m.index < r.end)
    if (overlap) continue
    frags.push({ kind: 'frag', frag: f, raw: m[0], start: m.index, end: m.index + m[0].length })
  }
  if (frags.length === 0) return null
  frags.sort((a, b) => a.start - b.start)

  let has = false
  let out = ''
  let last = 0
  for (const { kind, frag, raw, start, end } of frags) {
    let rendered = null
    if (kind === 'display') {
      rendered = renderDelimited(frag, true)
    } else if (kind === 'inline') {
      rendered = renderDelimited(frag, false)
    } else {
      rendered = renderFragment(frag)
    }
    if (!rendered) continue
    has = true
    if (start > last) out += escapeHtml(text.slice(last, start))
    if (kind === 'display') {
      out += `<div class="math-display-block">${rendered}</div>`
    } else {
      out += `<span class="katex-inline-fallback" style="display:inline;vertical-align:baseline;">${rendered}</span>`
    }
    last = end
    // handle trailing spaces yang ikut di raw (khusus fragmen pola, bukan delimiter)
    if (kind === 'frag') {
      const trailing = raw.length - frag.length
      if (trailing > 0) last -= trailing
    }
  }
  if (!has) return null
  if (last < text.length) out += escapeHtml(text.slice(last))
  return out
}

const _cache = new Map()
export function prepareMathHtml(html) {
  if (!html || typeof html !== 'string') return html
  // Lenient code pass dulu (idempoten): fence ```...``` + backtick `...` jadi
  // <pre><code>/<code> rapi dan isi <pre> dipastikan ter-escape.
  // Ini memperbaiki semua konsumen (fill, builder, dashboard, AI preview)
  // tanpa mengubah tiap call-site. Strict pass untuk output mentah AI
  // tetap dilakukan eksplisit di AiFormBuilderPage sebelum memanggil ini.
  let src = html
  try {
    const converted = prepareCodeHtml(html)
    if (typeof converted === 'string') src = converted
  } catch { /* abaikan, lanjut dengan html asli */ }
  // <br> di dalam span rumus akan memecah delimiter saat split tag di bawah
  // (delimiter jadi tak lengkap dan rumus tampil mentah). Ganti dengan spasi
  // dulu — kecuali di dalam <pre> (kode program, jangan disentuh).
  try {
    src = src.replace(/(<pre[\s\S]*?<\/pre\s*>|\\\([\s\S]*?\\\)|\\\[[\s\S]*?\\\])/gi, (m) => {
      if (/^<pre/i.test(m)) return m
      return m.replace(/<br\s*\/?>/gi, ' ')
    })
  } catch { /* abaikan */ }
  const needsMath = src.includes('\\') || HAS_POW_SUB.test(src)
  HAS_POW_SUB.lastIndex = 0
  if (_cache.has(html)) return _cache.get(html)
  if (!needsMath) {
    _cache.set(html, src)
    if (_cache.size > 200) _cache.delete(_cache.keys().next().value)
    return src
  }
  // fast-path: sudah ada katex dan tidak ada raw math di luar annotation/data-value -> skip
  if (src.includes('katex')) {
    const stripped = src.replace(/<annotation[^>]*>[\s\S]*?<\/annotation>/g, '').replace(/data-(value|latex)="[^"]*"/g, '')
    const stillHas = stripped.includes('\\') ? HAS_LATEX.test(stripped) : HAS_POW_SUB.test(stripped)
    HAS_POW_SUB.lastIndex = 0
    if (!stillHas) {
      _cache.set(html, src)
      if (_cache.size > 200) _cache.delete(_cache.keys().next().value)
      return src
    }
  }
  // tag-aware split: hanya proses chunk text, bukan tag — skip di dalam <pre>/<code>
  const parts = src.split(/(<[^>]+>)/g)
  let changed = false
  let insidePre = 0
  let insideCode = 0
  for (let i = 0; i < parts.length; i++) {
    const p = parts[i]
    if (!p) continue
    if (p.startsWith('<')) {
      const lower = p.toLowerCase()
      if (/^<pre(\s|>)/.test(lower)) insidePre++
      else if (/^<\/pre\s*>/.test(lower)) insidePre = Math.max(0, insidePre - 1)
      else if (/^<code(\s|>)/.test(lower)) insideCode++
      else if (/^<\/code\s*>/.test(lower)) insideCode = Math.max(0, insideCode - 1)
      continue
    }
    if (insidePre > 0 || insideCode > 0) continue
    const enriched = enrichTextChunk(p)
    if (enriched !== null) {
      parts[i] = enriched
      changed = true
    }
  }
  // handle ql-formula kosong (old data) : <span class="ql-formula" data-value="\frac{3}{6}"></span>
  let out = changed ? parts.join('') : src
  if (out && typeof out === 'string' && out.includes('undefined')) {
    out = out
      .replace(/<div[^>]*class="[^"]*math-display-block[^"]*"[^>]*data-latex="undefined"[^>]*>.*?<\/div>/gi, '')
      .replace(/<div[^>]*class="[^"]*math-display-block[^"]*"[^>]*>\s*undefined\s*<\/div>/gi, '')
      .replace(/<span[^>]*class="[^"]*ql-formula[^"]*"[^>]*data-value="undefined"[^>]*>.*?<\/span>/gi, '');
    changed = true;
  }
  // jika ada ql-formula kosong, render sekali tanpa DOM (string replace ringan)
  if (out.includes('ql-formula') && out.includes('data-value')) {
    out = out.replace(/<span[^>]*class="[^"]*ql-formula[^"]*"[^>]*data-value="([^"]+)"[^>]*>\s*<\/span>/g, (full, latex) => {
      const rendered = renderFragment(latex)
      if (!rendered) return full
      return full.replace('></span>', `>${rendered}</span>`)
    })
    out = out.replace(/<div[^>]*class="[^"]*math-display-block[^"]*"[^>]*data-latex="([^"]+)"[^>]*>\s*<\/div>/g, (full, latex) => {
      try {
        const rendered = katex.renderToString(latex, { throwOnError: false, displayMode: true, strict: false })
        if (rendered.includes('katex-error')) return full
        return full.replace('></div>', `>${rendered}</div>`)
      } catch { return full }
    })
    if (out !== src) changed = true
  }
  const res = changed ? out : src
  _cache.set(html, res)
  if (_cache.size > 200) _cache.delete(_cache.keys().next().value)
  return res
}

export function getEnrichedMathHtml(html) {
  return prepareMathHtml(html)
}
