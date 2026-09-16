import DOMPurify from 'dompurify';

// Sanitasi terpusat untuk semua dangerouslySetInnerHTML.
// Backend sudah sanitasi, tapi defense-in-depth di client wajib karena
// label/judul bisa datang dari form lama, AI, atau import DOCX.
export function safeHtml(dirty) {
  if (!dirty || typeof dirty !== 'string') return '';
  return DOMPurify.sanitize(dirty, {
    ALLOWED_TAGS: [
      'p', 'br', 'strong', 'b', 'em', 'i', 'u', 's', 'strike', 'del',
      'span', 'ul', 'ol', 'li', 'h1', 'h2', 'h3', 'h4', 'blockquote',
      'a', 'sub', 'sup', 'font', 'div', 'pre', 'code', 'img', 'hr',
      'audio', 'video', 'source',
      'math', 'semantics', 'annotation', 'mrow', 'mfrac', 'mn', 'mo', 'mi',
      'msup', 'msub', 'msubsup', 'munder', 'mover', 'munderover',
      'mtable', 'mtr', 'mtd',
    ],
    ALLOWED_ATTR: [
      'href', 'title', 'target', 'rel', 'class', 'style',
      'src', 'alt', 'width', 'height', 'controls', 'preload', 'type',
      'start', 'color', 'face', 'size', 'xmlns', 'encoding',
      'data-value', 'data-latex', 'aria-hidden', 'spellcheck',
      'data-video', 'data-embed', 'data-type', 'data-original-src', 'data-rendered', 'data-ngrok-fixed', 'data-language',
    ],
    ALLOW_DATA_ATTR: false,
    // Tolak javascript:/data:text/html di href/src agar avatar/banner/file_url jahat tidak lolos.
    ALLOWED_URI_REGEXP: /^(?:(?:(?:f|ht)tps?|mailto|tel|callto|sms|cid|xmpp|blob):|[^a-z]|[a-z+.-]+(?:[^a-z+.-:]|$))/i,
    FORBID_TAGS: ['script', 'style', 'iframe', 'object', 'embed', 'form', 'link', 'meta', 'base', 'svg'],
    FORBID_ATTR: ['onerror', 'onload', 'onclick', 'onmouseover', 'onfocus', 'onblur', 'onmouseenter', 'onmouseleave', 'onloadstart', 'onerror'],
  });
}

const _SAFE_SRC_RE = /^(https?:\/\/|blob:|data:image\/)/i;

// Validasi URL gambar/avatar/banner sebelum dirender ke <img src>.
export function isSafeImageUrl(url) {
  if (!url || typeof url !== 'string') return false;
  const s = url.trim();
  if (!s) return false;
  const low = s.toLowerCase();
  if (low.startsWith('javascript:') || low.startsWith('data:text/html')) return false;
  return _SAFE_SRC_RE.test(s);
}
