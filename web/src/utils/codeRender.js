/**
 * codeRender — normalisasi snippet code (HTML/CSS/JS/Python/dll) agar aman
 * dirender via dangerouslySetInnerHTML + DOMPurify tanpa menjadi kosong.
 *
 * Masalah asal: AI mengembalikan tag mentah seperti "fungsi tag <p>" atau opsi
 * "<div class=...>" / "<table>...". Tag itu dianggap elemen HTML beneran lalu
 * di-strip DOMPurify (table/tr/td/input/form tidak di-allow) -> soal/opsi kosong.
 *
 * Dua mode:
 * - strict:true  -> untuk output mentah AI (AiFormBuilderPage preview).
 *                   Bare tag di luar <pre>/<code> di-escape menjadi entities
 *                   + dibungkus <code> inline (atau <pre><code> bila multi-baris).
 * - strict:false -> untuk konten editor/fill (Quill). Hanya konversi fence
 *                   ```lang ... ``` + backtick inline + rapikan isi <pre>,
 *                   tag rich-text lain dibiarkan apa adanya.
 */

const CODE_TAG_RE =
  /<\/?(?:html|head|body|title|meta|link|div|span|p|a|img|ul|ol|li|table|thead|tbody|tr|td|th|form|input|button|select|option|textarea|label|h1|h2|h3|h4|h5|h6|header|footer|section|article|nav|main|aside|style|script|pre|code|blockquote|br|hr)(?:\s[^<>]*)?\/?>/gi;
const FENCE_RE = /```(\w*)\s*\n?([\s\S]*?)```/g;
const PRE_BLOCK_RE = /<pre(\s[^>]*)?>([\s\S]*?)<\/pre\s*>/gi;
const INLINE_CODE_RE = /<code(\s[^>]*)?>[\s\S]*?<\/code\s*>/gi;

function escapeHtml(s) {
  return String(s ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

function escapeCodeText(code) {
  if (!code) return '';
  if (code.includes('&lt;') || code.includes('&gt;')) return code;
  return escapeHtml(code).replace(/&quot;/g, '&quot;');
}

function normLang(lang) {
  const l = (lang || 'html').trim().toLowerCase() || 'html';
  if (l === 'htm') return 'html';
  if (l === 'js') return 'javascript';
  if (l === 'py') return 'python';
  return l;
}

function fixPreBlock(full, attrs, inner) {
  const a = attrs || '';
  const cm = inner.match(/<code(\s[^>]*)?>([\s\S]*?)<\/code\s*>/i);
  if (cm) {
    let codeAttrs = cm[1] || '';
    let codeInner = cm[2] || '';
    if (codeInner.includes('<') && !codeInner.includes('&lt;')) {
      codeInner = escapeHtml(codeInner);
    }
    if (!/language-/i.test(codeAttrs)) {
      codeAttrs = `${codeAttrs} class="language-html"`;
    }
    const next = inner.replace(
      /<code(\s[^>]*)?>([\s\S]*?)<\/code\s*>/i,
      () => `<code${codeAttrs}>${codeInner}</code>`,
    );
    return `<pre${a}>${next}</pre>`;
  }
  let esc = inner;
  if (esc.includes('<') && !esc.includes('&lt;')) esc = escapeHtml(esc);
  return `<pre${a}><code class="language-html">${esc}</code></pre>`;
}

function convertFences(s) {
  return s.replace(FENCE_RE, (full, lang, code) => {
    const l = normLang(lang);
    return `<pre><code class="language-${l}">${escapeCodeText((code || '').trim())}</code></pre>`;
  });
}

function convertBackticks(s) {
  if (!s.includes('`')) return s;
  return s.replace(/`([^`\n]+)`/g, (full, code) => `<code>${escapeCodeText(code)}</code>`);
}

export function prepareCodeHtml(html, opts = {}) {
  if (!html || typeof html !== 'string') return html;
  const strict = !!opts.strict;
  let s = html;

  // 1) Rapikan <pre> yang sudah ada (jangan nested ganda).
  if (/<pre[\s>]/i.test(s)) {
    s = s.replace(PRE_BLOCK_RE, fixPreBlock);
    if (!strict) return convertBackticks(s);
  }

  // 2) Lindungi inline <code> yang sudah benar (hindari double-escape).
  // Placeholder berupa token teks biasa (tanpa control char agar lolos lint).
  const stash = [];
  const ph = (i) => `__F4XCODE${i}__`;
  s = s.replace(INLINE_CODE_RE, (m) => {
    stash.push(m);
    return ph(stash.length - 1);
  });
  const restore = (t) => {
    let out = t;
    stash.forEach((orig, i) => {
      out = out.split(ph(i)).join(orig);
    });
    return out;
  };

  // 3) Fence markdown -> <pre><code> block rapi.
  s = convertFences(s);

  if (!strict) {
    s = convertBackticks(s);
    return restore(s);
  }

  // ---- strict mode (output mentah AI): escape bare tag ----
  CODE_TAG_RE.lastIndex = 0;
  const hasRawTag = s.includes('<') && CODE_TAG_RE.test(s);
  CODE_TAG_RE.lastIndex = 0;

  if (!hasRawTag) {
    return restore(convertBackticks(s));
  }

  // Dokumen multi-baris (mis. "<html>\n<head>...") -> satu block rapi.
  CODE_TAG_RE.lastIndex = 0;
  if (s.includes('\n') && s.split('<').length - 1 >= 2) {
    CODE_TAG_RE.lastIndex = 0;
    if (CODE_TAG_RE.test(s)) {
      CODE_TAG_RE.lastIndex = 0;
      // Jangan bungkus kalau sudah berupa <pre> hasil konversi fence.
      if (!/<pre[\s>]/i.test(s)) {
        const withoutPh = s.replace(/__F4XCODE\d+__/g, '');
        if (withoutPh.includes('<')) {
          return restore(`<pre><code class="language-html">${escapeHtml(s)}</code></pre>`);
        }
      }
    }
  }

  // Kasus umum: tiap bare tag -> <code>&lt;tag&gt;</code>.
  CODE_TAG_RE.lastIndex = 0;
  s = s.replace(CODE_TAG_RE, (raw) => `<code>${escapeHtml(raw)}</code>`);
  s = convertBackticks(s);
  return restore(s);
}

/** Cek apakah HTML hasil sanitasi terlihat kosong (tag di-strip semua). */
export function isVisuallyEmpty(html) {
  if (!html || typeof html !== 'string') return true;
  if (/<(img|audio|video|source|hr)\b[^>]*>/i.test(html)) return false;
  const text = html
    .replace(/<[^>]+>/g, '')
    .replace(/&lt;/gi, '<')
    .replace(/&gt;/gi, '>')
    .replace(/&amp;/gi, '&')
    .replace(/&quot;/gi, '"')
    .replace(/&#39;|&apos;/gi, "'")
    .replace(/&nbsp;/gi, ' ')
    .trim();
  return text.length === 0;
}

/**
 * Fallback pengaman: kalau hasil sanitasi kosong padahal data mentah ada
 * (mis. opsi "<div>" lolos dari normalizer lama), tampilkan versi escaped
 * sebagai code agar tidak pernah blank.
 */
export function ensureVisibleCodeHtml(raw, sanitized) {
  if (!isVisuallyEmpty(sanitized)) return sanitized;
  if (!raw || (typeof raw === 'string' && raw.trim() === '')) return sanitized;
  return `<code>${escapeHtml(String(raw).slice(0, 2000))}</code>`;
}
