import katex from 'katex'

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

function enrichTextChunk(text) {
  if (!text) return null
  const hasLatex = HAS_LATEX.test(text)
  const hasPow = HAS_POW_SUB.test(text)
  // reset lastIndex untuk test global
  HAS_POW_SUB.lastIndex = 0
  if (!hasLatex && !hasPow) return null

  // kumpulkan semua fragment dari kedua pola, urut by index
  const frags = []
  let m
  SIMPLE_LATEX.lastIndex = 0
  while ((m = SIMPLE_LATEX.exec(text)) !== null) {
    const f = m[0].trim()
    if (f.length < 3) continue
    frags.push({ frag: f, raw: m[0], start: m.index, end: m.index + m[0].length })
  }
  PLAIN_POW_SUB.lastIndex = 0
  while ((m = PLAIN_POW_SUB.exec(text)) !== null) {
    const f = m[0].trim()
    if (f.length < 3) continue
    // hindari duplikat yang sudah tercakup oleh SIMPLE_LATEX (overlap)
    const overlap = frags.some(r => m.index >= r.start && m.index < r.end)
    if (overlap) continue
    frags.push({ frag: f, raw: m[0], start: m.index, end: m.index + m[0].length })
  }
  if (frags.length === 0) return null
  frags.sort((a, b) => a.start - b.start)

  let has = false
  let out = ''
  let last = 0
  for (const { frag, raw, start, end } of frags) {
    const rendered = renderFragment(frag)
    if (!rendered) continue
    has = true
    if (start > last) out += escapeHtml(text.slice(last, start))
    out += `<span class="katex-inline-fallback" style="display:inline-block;vertical-align:middle;margin:0 2px;">${rendered}</span>`
    last = end
    // handle trailing spaces yang ikut di raw (jika ada)
    const trailing = raw.length - frag.length
    if (trailing > 0) last -= trailing
  }
  if (!has) return null
  if (last < text.length) out += escapeHtml(text.slice(last))
  return out
}

const _cache = new Map()
export function prepareMathHtml(html) {
  if (!html || typeof html !== 'string') return html
  const needsMath = html.includes('\\') || HAS_POW_SUB.test(html)
  HAS_POW_SUB.lastIndex = 0
  if (!needsMath) return html
  if (_cache.has(html)) return _cache.get(html)
  // fast-path: sudah ada katex dan tidak ada raw math di luar annotation/data-value -> skip
  if (html.includes('katex')) {
    const stripped = html.replace(/<annotation[^>]*>[\s\S]*?<\/annotation>/g, '').replace(/data-(value|latex)="[^"]*"/g, '')
    const stillHas = stripped.includes('\\') ? HAS_LATEX.test(stripped) : HAS_POW_SUB.test(stripped)
    HAS_POW_SUB.lastIndex = 0
    if (!stillHas) {
      _cache.set(html, html)
      if (_cache.size > 200) _cache.delete(_cache.keys().next().value)
      return html
    }
  }
  // tag-aware split: hanya proses chunk text, bukan tag
  const parts = html.split(/(<[^>]+>)/g)
  let changed = false
  for (let i = 0; i < parts.length; i++) {
    const p = parts[i]
    if (!p || p.startsWith('<')) continue
    // skip jika di dalam <code> / <pre> -> cek context sederhana: lihat part sebelum yang mengandung <code
    // untuk ringan, cukup skip jika text mengandung \ dan enrich berhasil
    const enriched = enrichTextChunk(p)
    if (enriched !== null) {
      parts[i] = enriched
      changed = true
    }
  }
  // handle ql-formula kosong (old data) : <span class="ql-formula" data-value="\frac{3}{6}"></span>
  let out = changed ? parts.join('') : html
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
    if (out !== html) changed = true
  }
  const res = changed ? out : html
  _cache.set(html, res)
  if (_cache.size > 200) _cache.delete(_cache.keys().next().value)
  return res
}

export function getEnrichedMathHtml(html) {
  return prepareMathHtml(html)
}
